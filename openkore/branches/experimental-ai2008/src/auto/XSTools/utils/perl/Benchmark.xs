#include "../dense_hash_map.h"
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdlib.h>
#include <time.h>
#include <string.h>
#include <vector>
#include <list>


typedef double (*HR_Time_t) ();
static void *HR_Time_p = 0;
#define HR_Time ((HR_Time_t) HR_Time_p)

using namespace std;
using namespace google;

struct Item {
	clock_t clock;
	double realTime;

	Item() {
		clock = 0;
		realTime = 0;
	}
};

struct eqstr {
	bool operator()(const char* s1, const char* s2) const {
		return (s1 == s2) || (s1 && s2 && strcmp(s1, s2) == 0);
	}
};
typedef dense_hash_map<const char *, int, HASH_NAMESPACE::hash<const char *>, eqstr> StrIntMap;

class Benchmark {
private:
	StrIntMap domainToId;
	vector<Item *> measurements;
	vector<Item *> results;
	list<char *> domains;
public:
	Benchmark() {
		domainToId.set_empty_key(NULL);
	}

	~Benchmark() {
		vector<Item *>::iterator it;
		list<char *>::iterator it2;
		for (it = measurements.begin(); it != measurements.end(); it++) {
			delete *it;
		}
		for (it = results.begin(); it != results.end(); it++) {
			delete *it;
		}
		for (it2 = domains.begin(); it2 != domains.end(); it2++) {
			free(*it2);
		}
	}

	void begin(const char *domain) {
		Item *item;
		StrIntMap::iterator result = domainToId.find(domain);
		if (result == domainToId.end()) {
			char *domainCopy = strdup(domain);
			domains.push_front(domainCopy);
			domainToId[domainCopy] = measurements.size();
			item = new Item();
			measurements.push_back(item);
			results.push_back(new Item());
		} else {
			pair<const char *, int> p = *result;
			item = measurements[p.second];
		}

		item->clock = clock();
		item->realTime = HR_Time();
	}

	void end(const char *domain) {
		int id = domainToId[domain];
		Item *measurement = measurements[id];
		Item *result = results[id];

		result->clock += clock() - measurement->clock;
		result->realTime += HR_Time() - measurement->realTime;
	}

	const list<char *> getDomains() {
		return domains;
	}

	const Item * getResult(const char *domain) {
		int id = domainToId[domain];
		return results[id];
	}
};

static Benchmark benchmark;


MODULE = Utils::Benchmark	PACKAGE = Benchmark
PROTOTYPES: ENABLE

void
init()
CODE:
	SV **svp = hv_fetch(PL_modglobal, "Time::NVtime", 12, 0);
	if (!svp) {
		croak("Time::HiRes is required");
	}
	if (!SvIOK(*svp)) {
		croak("Time::NVtime isn't a function pointer");
	}
	HR_Time_p = INT2PTR(void *, SvIV (*svp));

void
begin(domain)
	char *domain
CODE:
	benchmark.begin(domain);

void
end(domain)
	char *domain
CODE:
	benchmark.end(domain);

SV *
getResults()
CODE:
	list<char *>::iterator it;
	list<char *> domains;
	HV *results;

	domains = benchmark.getDomains();
	results = (HV *) sv_2mortal((SV *) newHV());
	for (it = domains.begin(); it != domains.end(); it++) {
		const Item *item = benchmark.getResult(*it);
		HV *perl_item = (HV *) sv_2mortal((SV *) newHV());

		hv_store(perl_item, "clock", 5, newSViv(item->clock), 0);
		hv_store(perl_item, "realTime", 8, newSVnv(item->realTime), 0);
		hv_store(results, *it, strlen(*it), newRV((SV *) perl_item), 0);
	}
	RETVAL = newRV((SV *) results);
OUTPUT:
	RETVAL

double
clock2msec(clocktime)
	double clocktime
CODE:
	RETVAL = clocktime / (double) CLOCKS_PER_SEC;
OUTPUT:
	RETVAL

