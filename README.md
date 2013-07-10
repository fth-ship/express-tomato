# express-tomato

An [expressjs][] server and [angularjs][] client for using the
[Pomodoro Technique®][pomodoro]. Uses [sequelize][] for persistence.

To use as a standalone app, just start up the server:

    $ coffee main.coffee

Or if you was cloned the repo:
    
    $ sudo npm install -g lmj-tomato

    $ lmj-tomato -r [ path to the project ]

To mount within another express server, run the `.middleware()` method:

    app.use('/tomato', require('lmj-tomato').middleware(options))

Available options:

- **analytics** - a Google Analytics identifier
- **db** - sqlite database to use (defaults to =./tomato.db=)

[expressjs]: http://expressjs.com
[angularjs]: http://angularjs.org
[pomodoro]: http://www.pomodorotechnique.com
[sequelize]: http://sequelizejs.com

## Inspiration

Initial inspiration came from the lovely http://tomatoi.st/.

The Pomodoro Technique® was developed by Francesco Cirillo and appears to be a
registered trademark of the same.

## License

(The MIT License)

Copyright (c) 2011 Leif Johnson &lt;leif@leifjohnson.net&gt;

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the 'Software'), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
