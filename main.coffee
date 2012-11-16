# Copyright (c) 2011 Leif Johnson <leif@leifjohnson.net>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

_ = require 'underscore'
express = require 'express'
fs = require 'fs'
nib = require 'nib'
sqlz = require 'sequelize'
stitch = require 'stitch'
stylus = require 'stylus'
uglify = require 'uglify-js'


module.exports.middleware = (options) ->
  jsapp = stitch.createPackage
    paths: ["#{__dirname}/app"]
    dependencies: []

  jsapp.compile (err, source) ->
    {gen_code, ast_squeeze, ast_mangle} = uglify.uglify
    minified = gen_code ast_squeeze ast_mangle uglify.parser.parse source
    fs.writeFile "#{__dirname}/public/app.js", minified, (err) ->
      throw err if err
      console.log 'compiled app.js'

  db = new sqlz '', '', '', dialect: 'sqlite', storage: options?.db or 'tomato.db'

  # MODELS

  # works are individual work units -- something contributed to a task
  Work = db.define 'Work'
    id:
      type: sqlz.INTEGER
      primaryKey: true

  # tasks are individual line items in a tomato -- something to be accomplished
  Task = db.define 'Task'
    name:
      type: sqlz.STRING
      allowNull: false
      unique: true
    order:
      type: sqlz.INTEGER
      allowNull: false
      defaultValue: 0
    priority:
      type: sqlz.INTEGER
      allowNull: false
      defaultValue: 0
      validate: min: 0
    difficulty:
      type: sqlz.INTEGER
      allowNull: false
      defaultValue: 0
      validate: min: 0
    finishedAt: sqlz.DATE

  Task.hasMany Work

  # breaks are just labeled segments of time
  Break = db.define 'Break'
    name: sqlz.STRING

  # a tomato is a list of tasks and a list of breaks
  Tomato = db.define 'Tomato'
    user: sqlz.STRING
    slug:
      type: sqlz.STRING
      allowNull: false
      unique: true
      validate: regex: /^[^\/]+$/
    workSec:
      type: sqlz.INTEGER
      allowNull: false
      validate: min: 1
    breakSec:
      type: sqlz.INTEGER
      allowNull: false
      validate: min: 1

  Tomato.hasMany Task
  Tomato.hasMany Break

  db.sync().error (err) ->
    console.log err
    process.exit()

  # APP

  app = express()

  app.configure 'development', ->
    app.use express.errorHandler dumpExceptions: true, showStack: true

  app.configure 'production', ->
    app.use express.errorHandler()

  app.configure ->
    app.set 'views', __dirname
    app.set 'view options', layout: false
    app.set 'view engine', 'jade'
    app.use express.logger 'short'
    app.use stylus.middleware
      src: "#{__dirname}/public"
      compile: (str, path) ->
        stylus(str).set('filename', path).set('compress', true).use(nib())
    app.use express.methodOverride()
    app.use express.bodyParser()
    app.use express.static "#{__dirname}/public"
    app.use app.router

  app.get '/app.js', jsapp.createServer()

  # PARAMS

  app.param 'tomato', (req, res, next, slug) ->
    Tomato.find(where: slug: slug)
      .error(next)
      .success (tomato) ->
        return res.send(404) unless tomato
        req.tomato = tomato
        next()

  app.param 'task', (req, res, next, id) ->
    req.tomato.getTasks(where: id: id)
      .error(next)
      .success (ts) ->
        return res.send(404) unless ts.length is 1
        req.task = ts[0]
        next()

  app.param 'break', (req, res, next, id) ->
    req.tomato.getBreaks(where: id: id)
      .error(next)
      .success (bs) ->
        return res.send(404) unless bs.length is 1
        req.brake = bs[0]
        next()

  # ROUTES

  # GET / -- return html for creating a new tomato
  app.get '/', (req, res) ->
    ctx =
      analytics: options?.analytics
      basepath: (app.settings.basepath or '').replace /\/$/, ''
    res.render 'index', ctx

  # POST / -- create a new tomato
  app.post '/', (req, res) ->
    slug = req.param 'slug'
    Tomato.create(
      slug: slug
      workSec: 60 * req.param 'workMin'
      breakSec: 60 * req.param 'breakMin'
    )
      .error((err) -> res.send 500, err)
      .success(-> res.redirect "/#{slug}")

  # GET /:tomato -- return the html to drive the client-side tomato app
  app.get '/:tomato', (req, res) ->
    # keep the database clean by removing rotten tomatoes.
    Tomato.findAll(where: ['updatedAt < ?', Date.now() - 1000 * 86400 * 100])
      .success((ts) -> t.destroy() for t in ts)
    ctx =
      analytics: options?.analytics
      basepath: (app.settings.basepath or '').replace /\/$/, ''
      tomato: req.tomato
    res.render 'main', ctx

  # PUT /:tomato -- update the id, name, etc. of a tomato
  app.put '/:tomato', (req, res) ->
    fields = ['slug', 'workSec', 'breakSec']
    req.tomato.updateAttributes(req.body, fields)
      .error((err) -> res.send 500, err)
      .success(-> res.send 200)

  # DELETE /:tomato -- delete a tomato and all tasks and breaks
  app.del '/:tomato', (req, res) ->
    req.tomato.destroy()
      .error((err) -> res.send 500, err)
      .success(-> res.send 200)

  # GET /:tomato/tasks -- get all tasks for a tomato
  app.get '/:tomato/tasks', (req, res) ->
    req.tomato.getTasks()
      .error((err) -> res.send 500, err)
      .success((ts) -> res.send ts)

  # POST /:tomato/tasks -- create a new task for a tomato
  app.post '/:tomato/tasks', (req, res) ->
    Task.create(
      TomatoId: req.tomato.id
      name: req.param 'name'
      order: req.param 'order'
      priority: req.param 'priority'
      difficulty: req.param 'difficulty'
      finishedAt: null
    )
      .error((err) -> res.send 500, err)
      .success((t) -> res.send t)

  # GET /:tomato/tasks/:task -- return data for a task
  app.get '/:tomato/tasks/:task', (req, res) ->
    res.send req.task

  # PUT /:tomato/tasks/:task -- update data for a task
  app.put '/:tomato/tasks/:task', (req, res) ->
    fields = ['name', 'order', 'priority', 'difficulty', 'finishedAt']
    req.task.updateAttributes(req.body, fields)
      .error((err) -> res.send 500, err)
      .success(-> res.send 200)

  # DELETE /:tomato/tasks/:task -- remove a task
  app.del '/:tomato/tasks/:task', (req, res) ->
    req.task.destroy()
      .error((err) -> res.send 500, err)
      .success(-> res.send 200)

  # GET /:tomato/breaks -- get all breaks for a tomato
  app.get '/:tomato/breaks', (req, res) ->
    req.tomato.getBreaks()
      .error((err) -> res.send 500, err)
      .success((bs) -> res.send bs)

  # POST /:tomato/breaks -- create a new break for a tomato
  app.post '/:tomato/breaks', (req, res) ->
    Break.create(TomatoId: req.tomato.id, name: req.param 'name')
      .error((err) -> res.send 500, err)
      .success((b) -> res.send b)

  # GET /:tomato/breaks/:break -- return data for a break
  app.get '/:tomato/breaks/:break', (req, res) ->
    res.send req.brake

  # PUT /:tomato/breaks/:break -- update data for a break
  app.put '/:tomato/breaks/:break', (req, res) ->
    req.brake.updateAttributes(req.body, ['name'])
      .error((err) -> res.send 500, err)
      .success(-> res.send 200)

  # DELETE /:tomato/breaks/:break -- remove a break
  app.del '/:tomato/breaks/:break', (req, res) ->
    req.brake.destroy()
      .error((err) -> res.send 500, err)
      .success(-> res.send 200)

  return app


unless module.parent
  exports.middleware().listen 4000
  console.log 'tomato server listening on http://localhost:4000'
