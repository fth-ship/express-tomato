(function () {
    'use strict';
    var tomato = require('commander'),
        spawn = require('child_process').spawn,
        path = require('path'),
        pack = require('../package');

    tomato
        .version( pack['version'] )
        .option('-r, --run [project path]', 'Run tamato application.')
        .parse( process.argv );

    if ( tomato.run ) {
        var server = spawn('coffee', [
            'main.coffee'    
        ], {
            pwd: path.join( __dirname, tomato.run ) 
        });

        server.stdout.on('data', function ( chunk ) {
            console.log( chunk.toString('utf-8') );
        });

        server.stderr.on('data', function ( chunk ) {
            console.log( chunk.toString('utf-8') );
        });

        server.on('error', function ( err ) {
            console.log( err.toString('utf-8') );
        });
    }
}).call( this );
