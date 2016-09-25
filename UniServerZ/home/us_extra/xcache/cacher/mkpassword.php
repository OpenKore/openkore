<html>
	<head>
		<title>Simple MD5 password generator</title>
	</head>
	<body>
		<h1>Simple MD5 password generator</h1>
		<form method="post">
			<fieldset>
				md5: <input type="password" name="password"> <input type="submit"><br>
				<div>
				<?php
				if ($_SERVER['REQUEST_METHOD'] == 'POST') {
					$md5 = md5(@ $_POST['password']);
					$offs = mt_rand(0 + 1, 31 - 1);
					$md5_1 = substr($md5, 0, $offs);
					$md5_2 = substr($md5, $offs);
					echo "Result: <span>$md5_1</span><span>$md5_2</span>";
				}
				?>
				</div>
			</fieldset>
		</form>
	</body>
</html>
