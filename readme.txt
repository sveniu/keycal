
Intrikat keycounter v0.2 2004-05-01
-----------------------------------

This program uses a system wide keyboard hook
to capture all keyboard events. It counts various
keys to generate slightly amusing statistics.

When you exit the program, the counters are stored
as a binary value in the registry at

HKEY_LOCAL_MACHINE\SOFTWARE\Intrikat_keycounter\Counters

The counters are restored on program start.

As of now, there are many features left out. See
the file docs/todo.txt for details.


This program and its accompanying source and
documentation is released under the zlib/libpng
license. See the file license.txt in the program
directory.

If you were to modify the program, and feel like
sharing, I'd be happy to hear from you.


How to build
------------

The included build.bat assume a working MASM >=7
installation on the same drive as the source is
located. The .bat-files should be self explanatory.


Contact
-------

Email: sveiulla@stud.aitel.hist.no
IRC:   sven @ EFnet


Some notes on generating trivia
-------------------------------

Trivia are very suitable for a program like this.
The user might not be in desperate need of knowing
how keyboard use compares to a 20 minute run, but
things like that generate instant awe.

I found some information about keyboards which are
relevant in this case:

Average keyswitch travel:  0.140±0.020 in. (3.56±0.5 mm)
Operating force:           2.0±0.5 oz. (57.1±14.2 grams)
Operating force, spacebar: 3.0±0.5 oz.

To find force and work, we apply some simple physics:

Force = mass * acceleration = 60g * 9.81m/s2 ~= 0.59N

Work = force * distance = 0.59 * 3.6mm = 0.00211896J

And then, to satisfy those who like fitness, we find:

1 cal equals 4.186 Joules, which gives us:

0.00211896J / 4.186 = 0.000506 cal

Now it's only a matter of finding things to compare
with. Typical activities include: running, sleeping,
lifting various objects, etc.
