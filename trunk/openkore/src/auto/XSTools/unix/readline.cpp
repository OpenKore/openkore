/* Perl interface for GNU readline */
#include <stdio.h>
#include <readline/readline.h>
#include <readline/history.h>
#include <pthread.h>
#include <list>

using namespace std;


/* Variables */
static pthread_t thread;

static bool quit;
static list<char *> input_list;

static int point, mark;
static char *line_buffer;

static pthread_mutex_t input_list_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_mutex_t quit_lock = PTHREAD_MUTEX_INITIALIZER;


/* Static/callback functions */
static void *
reader_thread (void *data)
{
	while (1) {
		char *line;
		bool my_quit;

		pthread_mutex_lock (&quit_lock);
		my_quit = quit;
		pthread_mutex_unlock (&quit_lock);

		if (quit)
			return NULL;

		line = readline (NULL);
		if (line && *line)
			add_history (line);

		pthread_mutex_lock (&input_list_lock);
		input_list.push_back (line);
		pthread_mutex_unlock (&input_list_lock);
	}
	return NULL;
}

static int
event_hook ()
{
	pthread_mutex_lock (&quit_lock);
	if (quit)
		rl_done = 1;
	pthread_mutex_unlock (&quit_lock);
	return 0;
}


/*********************
 * Public functions
 *********************/

extern "C" {

/*
 * Initialize this library.
 */
void
R_init ()
{
	quit = false;
	rl_event_hook = event_hook;
	setvbuf (stdout, NULL, _IOFBF, 0);
	pthread_create (&thread, NULL, reader_thread, NULL);
}


/*
 * Stop this library.
 */
void
R_stop ()
{
	pthread_mutex_lock (&quit_lock);
	quit = true;
	pthread_mutex_unlock (&quit_lock);
	pthread_join (thread, NULL);
	setlinebuf (stdout);
}

/*
 * Check whether there's a line in the input list
 * and retrieve it if possible.
 */
char *
R_pop ()
{
	char *result = NULL;

	pthread_mutex_lock (&input_list_lock);
	if (input_list.size () > 0) {
		result = input_list.front ();
		input_list.pop_front ();
	}
	pthread_mutex_unlock (&input_list_lock);

	return result;
}

/*
 * Hide the prompt.
 */
void
R_hide ()
{
	point = rl_point;
	mark = rl_mark;
	rl_mark = rl_point = 0;
	line_buffer = strdup (rl_line_buffer);
	rl_replace_line ("", 1);
	rl_redisplay ();
	rl_deprep_terminal ();
}

/*
 * Restore the prompt.
 */
void
R_show ()
{
	rl_prep_terminal (0);
	rl_replace_line (line_buffer, 1);
	free (line_buffer);
	rl_point = point;
	rl_mark = mark;
	rl_redisplay ();
}

/*
 * Set readline's prompt
 */
void
R_setPrompt (const char *prompt)
{
	rl_set_prompt (prompt);
}

/*
 * Print a message to the console using libc's printf()
 * because we want to print a message and the prompt in
 * the same flush. Perl's print might conflict with
 * libc's buffer.
 */
void
R_print (const char *msg)
{
	printf ("%s", msg);
}


} /* extern "C" */
