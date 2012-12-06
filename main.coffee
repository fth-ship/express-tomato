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
nib = require 'nib'
sqlz = require 'sequelize'
stitch = require 'stitch'
stylus = require 'stylus'
uglify = require 'uglify-js'

jsapp = stitch.createPackage
  paths: ["#{__dirname}/app"]
  dependencies: []

module.exports.middleware = (options) ->
  db = new sqlz '', '', '',
    dialect: 'sqlite'
    storage: options?.db or 'tomato.db'
    define:
      classMethods:
        findAll_: (opts, cb) ->
          @findAll(opts).error(cb).success (xs) -> cb null, xs
        find_: (opts, cb) ->
          @find(opts).error(cb).success (x) -> cb null, x
        create_: (opts, cb) ->
          @create(opts).error(cb).success (x) -> cb null, x
      instanceMethods:
        updateAttributes_: (data, fields, cb) ->
          @updateAttributes(data, fields).error(cb).success (x) -> cb null, x
        save_: (cb) ->
          @save().error(cb).success (x) -> cb null, x
        destroy_: (cb) ->
          @destroy().error(cb).success -> cb null

  prefix = options?.prefix or 'tomato_'

  # MODELS

  # works are timed work periods -- something contributed to a task
  Work = db.define "#{prefix}Work",
    {
      id:
        type: sqlz.INTEGER
        primaryKey: true
    },
    freezeTableName: true

  # tasks are individual line items in a tomato -- something to be accomplished
  Task = db.define "#{prefix}Task",
    {
      name:
        type: sqlz.STRING
        allowNull: false
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
    },
    freezeTableName: true

  Task.hasMany Work, foreignKey: 'taskId'

  # breaks are just labeled segments of time
  Break = db.define "#{prefix}Break",
    {
      name: sqlz.STRING
    },
    freezeTableName: true

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

  app = express()

  app.configure ->
    app.set 'basepath', -> "#{app.path()}/"
    app.set 'analytics', options?.analytics
    app.set 'views', __dirname
    app.set 'view options', layout: false
    app.set 'view engine', 'jade'
    app.use stylus.middleware
      src: "#{__dirname}/public"
      compile: (str, path) ->
        stylus(str).set('filename', path).set('compress', true).use(nib())
    app.use express.methodOverride()
    app.use express.bodyParser()
    app.use express.static "#{__dirname}/public", maxAge: 7 * 86400 * 1000
    app.use app.router

  app.configure 'development', ->
    app.use express.errorHandler dumpExceptions: true, showStack: true
    app.get '/tomato.js', jsapp.createServer()

  app.configure 'production', ->
    app.use express.errorHandler()
    jsapp.compile (err, source) ->
      {gen_code, ast_squeeze, ast_mangle} = uglify.uglify
      minified = gen_code ast_squeeze uglify.parser.parse source
      fs.writeFile "#{__dirname}/public/tomato.js", minified, (err) ->
        throw err if err
        console.log "compiled #{__dirname}/public/tomato.js"

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
      slug = req.param 'slug'
      opts = slug: slug, user: name, workMin: req.param 'workMin'
      Tomato.create_ opts, (err, tomato) ->
        return next(err) if err
        res.redirect "#{slug}/"

  # GET /:tomato -- return the html to drive the client-side tomato app
  app.get '/:tomato', (req, res) ->
    # remove tomatoes that haven't been updated in 100d.
    old = ['updatedAt < ?', new Date Date.now() - 86400000 * 100]
    Tomato.findAll(where: old).success((ts) -> t.destroy() for t in ts)
    res.render 'main', tomato: req.tomato

  # -- TOMATOES --

  app.param 'tomato', (req, res, next, slug) ->
    getUserName req, (err, name) ->
      Tomato.find_ where: {slug: slug, user: name}, (err, tomato) ->
        return next(err) if err
        return res.send(404) unless tomato
        req.tomato = tomato
        next()

  # GET /:tomato/tomato -- return json for a tomato
  app.get '/:tomato/tomato', (req, res) ->
    res.send req.tomato

  # POST /:tomato/tomato -- update the id, name, etc. of a tomato
  app.post '/:tomato/tomato', (req, res, next) ->
    req.tomato.updateAttributes_ req.body, ['slug', 'workMin'], (err, tomato) ->
      return next(err) if err
      res.send tomato

  # DELETE /:tomato -- delete a tomato and all tasks and breaks
  app.del '/:tomato/tomato', (req, res, next) ->
    req.tomato.destroy_ (err) ->
      return next(err) if err
      res.send 200

  # -- TASKS --

  app.param 'task', (req, res, next, id) ->
    Task.find_ where: {tomatoId: req.tomato.id, id: id}, (err, task) ->
      return next(err) if err
      return res.send(404) unless task
      req.task = task
      next()

  # GET /:tomato/tasks -- get all tasks for a tomato
  app.get '/:tomato/tasks', (req, res, next) ->
    Task.findAll_ where: {tomatoId: req.tomato.id}, (err, tasks) ->
      return next(err) if err
      res.send tasks

  # POST /:tomato/tasks -- create a new task for a tomato
  app.post '/:tomato/tasks', (req, res, next) ->
    opts =
      tomatoId: req.tomato.id
      name: req.param 'name'
      priority: req.param 'priority'
      difficulty: req.param 'difficulty'
      finishedAt: null
    Task.create_ opts, (err, task) ->
      return next(err) if err
      req.tomato.save()
      res.send task

  # POST /:tomato/tasks/:task -- update data for a task
  app.post '/:tomato/tasks/:task', (req, res, next) ->
    fields = ['name', 'priority', 'difficulty', 'finishedAt']
    req.task.updateAttributes_ req.body, fields, (err, task) ->
      return next(err) if err
      req.tomato.save()
      res.send task

  # DELETE /:tomato/tasks/:task -- remove a task
  app.del '/:tomato/tasks/:task', (req, res, next) ->
    req.task.destroy_ (err) ->
      return next(err) if err
      req.tomato.save()
      res.send 200

  # -- WORKS --

  app.param 'work', (req, res, next, id) ->
    Work.find_ where: {tomatoId: req.tomato.id, id: id}, (err, work) ->
      return next(err) if err
      return res.send(404) unless work
      req.work = work
      next()

  # GET /:tomato/works -- return work periods
  app.get '/:tomato/works', (req, res, next) ->
    Work.findAll_ where: {tomatoId: req.tomato.id}, (err, works) ->
      return next(err) if err
      res.send works

  # POST /:tomato/works -- start work period
  app.post '/:tomato/works', (req, res, next) ->
    query = tomatoId: req.tomato.id, id: req.param 'taskId'
    Task.find_ where: query, (err, task) ->
      return next(err) if err
      Work.create_ tomatoId: task.tomatoId, taskId: task.id, (err, work) ->
        return next(err) if err
        req.tomato.save()
        res.send work

  # POST /:tomato/works/:work -- finish work period
  app.post '/:tomato/works/:work', (req, res, next) ->
    req.work.save_ (err, work) ->
      return next(err) if err
      req.tomato.save()
      res.send work

  # DELETE /:tomato/works/:work -- cancel work period
  app.del '/:tomato/works/:work', (req, res, next) ->
    req.work.destroy_ (err) ->
      return next(err) if err
      req.tomato.save()
      res.send 200

  # -- BREAKS --

  app.param 'break', (req, res, next, id) ->
    Break.find_ where: {tomatoId: req.tomato.id, id: id}, (err, brake) ->
      return next(err) if err
      return res.send(404) unless brake
      req.brake = brake
      next()

  # GET /:tomato/breaks -- get all breaks for a tomato
  app.get '/:tomato/breaks', (req, res, next) ->
    Break.findAll_ where: {tomatoId: req.tomato.id}, (err, brakes) ->
      return next(err) if err
      res.send brakes

  # POST /:tomato/breaks -- create a new break for a tomato
  app.post '/:tomato/breaks', (req, res, next) ->
    opts = tomatoId: req.tomato.id, name: req.param 'name'
    Break.create_ opts, (err, brake) ->
      return next(err) if err
      req.tomato.save()
      res.send brake

  # POST /:tomato/breaks/:break -- update data for a break
  app.post '/:tomato/breaks/:break', (req, res, next) ->
    req.brake.updateAttributes_ req.body, ['name'], (err, brake) ->
      return next(err) if err
      req.tomato.save()
      res.send brake

  # DELETE /:tomato/breaks/:break -- remove a break
  app.del '/:tomato/breaks/:break', (req, res, next) ->
    req.brake.destroy_ (err) ->
      return next(err) if err
      req.tomato.save()
      res.send 200

  return app


unless module.parent
  exports.middleware().listen 4000
  console.log 'tomato server listening on http://localhost:4000'
