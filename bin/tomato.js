(function () {
    'use strict';
    var tomato = require('commander'),
        spawn = require('child_process').spawn,
        path = require('path'),
        pack = require('../package');

    tomato
        .version( pack['version'] )
        .option('-r, --run', 'Run tamato application.')
        .parse( process.argv );

    if ( tomato.run ) {
        console.log( __dirname );
        var server = spawn('coffee', [
            'main.coffee'    
        ], {
            pwd: path.join( __dirname, '..' ) 
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
