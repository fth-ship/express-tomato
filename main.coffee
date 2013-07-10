# Copyright (c) 2011-2012 Leif Johnson <leif@leifjohnson.net>
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
moment = require 'moment'
nib = require 'nib'
querystring = require 'querystring'
sqlz = require 'sequelize'
stitch = require 'stitch'
stylus = require 'stylus'
uglify = require 'uglify-js'

jsapp = stitch.createPackage paths: ["#{__dirname}/assets/js"]

exports.middleware = (options) ->
  db = new sqlz '', '', '',
    dialect: 'sqlite'
    storage: options?.db or 'tomato.db'
    logging: false

  prefix = options?.prefix or 'tomato_'

  # MODELS

  # breaks are labeled segments of time not associated with a specific task
  Break = db.define "#{prefix}Break",
    {
      name: { type: sqlz.STRING, allowNull: false }

      start_utc: { type: sqlz.DATE, allowNull: false }
      start_zone: { type: sqlz.INTEGER, allowNull: false }
      start_lat: sqlz.FLOAT
      start_lng: sqlz.FLOAT
      start_acc: sqlz.FLOAT

      stop_utc: sqlz.DATE
      stop_zone: sqlz.INTEGER
      stop_lat: sqlz.FLOAT
      stop_lng: sqlz.FLOAT
      stop_acc: sqlz.FLOAT
    },
    freezeTableName: true
    timestamps: false

  # works are timed work periods -- something contributed to a task
  Work = db.define "#{prefix}Work",
    {
      id: { type: sqlz.INTEGER, primaryKey: true }

      start_utc: { type: sqlz.DATE, allowNull: false }
      start_zone: { type: sqlz.INTEGER, allowNull: false }
      start_lat: sqlz.FLOAT
      start_lng: sqlz.FLOAT
      start_acc: sqlz.FLOAT

      stop_utc: sqlz.DATE
      stop_zone: sqlz.INTEGER
      stop_lat: sqlz.FLOAT
      stop_lng: sqlz.FLOAT
      stop_acc: sqlz.FLOAT
    },
    freezeTableName: true
    timestamps: false

  # tasks are individual line items in a tomato -- something to be accomplished
  Task = db.define "#{prefix}Task",
    {
      name: sqlz.STRING
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
      finish_utc: sqlz.DATE
      create_utc: sqlz.DATE
    },
    freezeTableName: true
    timestamps: false

  Task.hasMany Work, foreignKey: 'taskId'

  # a tomato is a list of tasks and a list of breaks
  Tomato = db.define "#{prefix}Tomato",
    {
      user: sqlz.STRING
      slug:
        type: sqlz.STRING
        allowNull: false
        unique: true
        validate: regex: /^[^\/]+$/
      workMin:
        type: sqlz.INTEGER
        allowNull: false
        validate: min: 1
    },
    freezeTableName: true

  Tomato.hasMany Work, foreignKey: 'tomatoId'
  Tomato.hasMany Task, foreignKey: 'tomatoId'
  Tomato.hasMany Break, foreignKey: 'tomatoId'

  db.sync().error (err) ->
    console.log err
    process.exit()

  # APP

  __static = options?.static or "#{__dirname}/public"

  app = express()

  app.configure ->
    app.set 'analytics', options?.analytics
    app.set 'views', __dirname
    app.set 'view options', layout: false
    app.set 'view engine', 'jade'
    app.set 'strict routing', true

    #app.use express.logger 'short'
    app.use express.methodOverride()
    app.use express.bodyParser()
    app.use stylus.middleware(
       src: "#{__dirname}/assets/css"
       dest: __static
       compile: (str, path) ->
         stylus(str)
           .set('filename', path)
           .set('compress', true)
           .use(nib()))
    app.use express.static __static, maxAge: 7 * 86400000
    app.use app.router

  app.configure 'development', ->
    app.get '/tomato.js', jsapp.createServer()

  app.configure 'production', ->
    jsapp.compile (err, source) ->
      throw err if err
      minified = uglify.minify source, fromString: true, mangle: false
      fs.writeFile "#{__static}/tomato.js", minified.code, (err) ->
        throw err if err
        console.log "compiled #{__static}/tomato.js"

  # AUTH

  z = options?.userName or null
  getUserName = if typeof z is 'function' then z else (r, cb) -> cb(null, z)

  # GET / -- return html for creating a new tomato
  app.get '/', (req, res) ->
    res.render 'index'

  # POST / -- create a new tomato
  app.post '/', (req, res, next) ->
    getUserName req, (err, name) ->
      return next(err) if err
      slug = req.body.slug
      opts = slug: slug, user: name, workMin: req.body.workMin
      Tomato.create(opts).done (err, tomato) ->
        return next(err) if err
        res.redirect "#{querystring.escape slug}/"

  # GET /:tomato -- return the html to drive the client-side tomato app
  app.get '/:tomato', (req, res) ->
    res.redirect "#{querystring.escape req.tomato.slug}/"
  app.get '/:tomato/', (req, res) ->
    # remove tomatoes that haven't been updated in 100d.
    old = ['updatedAt < ?', moment.utc().subtract('days', 100).format()]
    Tomato.findAll(where: old).success((ts) -> t.destroy() for t in ts)
    res.render 'main', tomato: req.tomato

  # -- TOMATOES --

  app.param 'tomato', (req, res, next, slug) ->
    getUserName req, (err, name) ->
      Tomato.find(where: slug: slug, user: name).done (err, tomato) ->
        return next(err) if err
        return next(status: 404) unless tomato
        req.tomato = tomato
        next()

  # GET /:tomato/tomato -- return json for a tomato
  app.get '/:tomato/tomato', (req, res) ->
    res.send req.tomato

  # POST /:tomato/tomato -- update the id, name, etc. of a tomato
  app.post '/:tomato/tomato', (req, res, next) ->
    req.tomato.updateAttributes(req.body, ['slug', 'workMin']).done (err, tomato) ->
      return next(err) if err
      res.send tomato

  # DELETE /:tomato -- delete a tomato and all tasks and breaks
  app.del '/:tomato/tomato', (req, res, next) ->
    req.tomato.destroy().done (err) ->
      return next(err) if err
      res.send 200

  # -- TASKS --

  app.param 'task', (req, res, next, id) ->
    Task.find(where: tomatoId: req.tomato.id, id: id).done (err, task) ->
      return next(err) if err
      return next(status: 404) unless task
      req.task = task
      next()

  # GET /:tomato/tasks -- get all tasks for a tomato
  app.get '/:tomato/tasks', (req, res, next) ->
    Task.findAll(where: tomatoId: req.tomato.id, {raw: true}).done (err, tasks) ->
      return next(err) if err
      res.send tasks

  # POST /:tomato/tasks -- create a new task for a tomato
  app.post '/:tomato/tasks', (req, res, next) ->
    opts =
      tomatoId: req.tomato.id
      name: req.body.name
      priority: req.body.priority
      difficulty: req.body.difficulty
      create_utc: moment.utc().toDate()
      finish_utc: moment.utc(0).toDate()
    Task.create(opts).done (err, task) ->
      return next(err) if err
      req.tomato.save()
      res.send task

  # POST /:tomato/tasks/:task -- update data for a task
  app.post '/:tomato/tasks/:task', (req, res, next) ->
    fields = ['name', 'priority', 'difficulty', 'finish_utc']
    req.task.updateAttributes(req.body, fields).done (err, task) ->
      return next(err) if err
      req.tomato.save()
      res.send task

  # DELETE /:tomato/tasks/:task -- remove a task
  app.del '/:tomato/tasks/:task', (req, res, next) ->
    req.task.destroy().done (err) ->
      return next(err) if err
      req.tomato.save()
      res.send 200

  # -- WORKS --

  app.param 'work', (req, res, next, id) ->
    Work.find(where: tomatoId: req.tomato.id, id: id).done (err, work) ->
      return next(err) if err
      return next(status: 404) unless work
      req.work = work
      next()

  # GET /:tomato/works -- return work periods
  app.get '/:tomato/works', (req, res, next) ->
    Work.findAll(where: tomatoId: req.tomato.id, {raw: true}).done (err, works) ->
      return next(err) if err
      res.send works

  # POST /:tomato/works -- start work period
  app.post '/:tomato/works', (req, res, next) ->
    query = tomatoId: req.tomato.id, id: req.query.taskId
    Task.find(where: query).done (err, task) ->
      return next(err) if err
      fields =
        tomatoId: req.tomato.id
        taskId: task.id
        start_utc: req.body.start_utc
        start_zone: req.body.start_zone
        start_lat: req.body.start_lat
        start_lng: req.body.start_lng
        start_acc: req.body.start_acc
        stop_utc: moment.utc(0).toDate()
      Work.create(fields).done (err, work) ->
        return next(err) if err
        req.tomato.save()
        res.send work

  # POST /:tomato/works/:work -- finish work period
  app.post '/:tomato/works/:work', (req, res, next) ->
    fields = ['stop_utc', 'stop_zone', 'stop_lat', 'stop_lng', 'stop_acc']
    req.work.updateAttributes(req.body, fields).done (err, work) ->
      return next(err) if err
      req.tomato.save()
      res.send work

  # DELETE /:tomato/works/:work -- cancel work period
  app.del '/:tomato/works/:work', (req, res, next) ->
    req.work.destroy().done (err) ->
      return next(err) if err
      req.tomato.save()
      res.send 200

  # -- BREAKS --

  app.param 'break', (req, res, next, id) ->
    Break.find(where: tomatoId: req.tomato.id, id: id).done (err, brake) ->
      return next(err) if err
      return next(status: 404) unless brake
      req.brake = brake
      next()

  # GET /:tomato/breaks -- get all breaks for a tomato
  app.get '/:tomato/breaks', (req, res, next) ->
    Break.findAll(where: tomatoId: req.tomato.id, {raw: true}).done (err, brakes) ->
      return next(err) if err
      res.send brakes

  # POST /:tomato/breaks -- create a new break for a tomato
  app.post '/:tomato/breaks', (req, res, next) ->
    fields =
      tomatoId: req.tomato.id
      name: req.body.name
      start_utc: req.body.start_utc
      start_zone: req.body.start_zone
      start_lat: req.body.start_lat
      start_lng: req.body.start_lng
      start_acc: req.body.start_acc
      stop_utc: moment.utc(0).toDate()
    Break.create(fields).done (err, brake) ->
      return next(err) if err
      req.tomato.save()
      res.send brake

  # POST /:tomato/breaks/:break -- update data for a break
  app.post '/:tomato/breaks/:break', (req, res, next) ->
    fields = ['stop_utc', 'stop_zone', 'stop_lat', 'stop_lng', 'stop_acc']
    req.brake.updateAttributes(req.body, fields).done (err, brake) ->
      return next(err) if err
      req.tomato.save()
      res.send brake

  # DELETE /:tomato/breaks/:break -- remove a break
  app.del '/:tomato/breaks/:break', (req, res, next) ->
    req.brake.destroy().done (err) ->
      return next(err) if err
      req.tomato.save()
      res.send 200

  return app


unless module.parent
  exports.middleware().listen 4000
  console.log 'tomato server listening on http://localhost:4000'
