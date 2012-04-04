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
crypto = require 'crypto'
express = require 'express'
fs = require 'fs'
mongoose = require 'mongoose'
nib = require 'nib'
stitch = require 'stitch'
stylus = require 'stylus'
uglify = require 'uglify-js'


module.exports.middleware = (options) ->
  desktop = stitch.createPackage
    paths: ["#{__dirname}/desktop"]
    dependencies: [
      "#{__dirname}/public/js/jquery.js"
      "#{__dirname}/public/js/jquery-ui.js"
      "#{__dirname}/public/js/underscore.js"
      "#{__dirname}/public/js/backbone.js"
      ]

  desktop.compile (err, source) ->
    {gen_code, ast_squeeze, ast_mangle} = uglify.uglify
    minified = gen_code ast_squeeze ast_mangle uglify.parser.parse source
    fs.writeFile "#{__dirname}/public/desktop.js", minified, (err) ->
      throw err if err
      console.log 'compiled desktop.js'

  # set up a private string to detect values that aren't present during POSTs
  ALPHA = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+-'
  rc = -> ALPHA[Math.floor Math.random() * ALPHA.length]
  NOTPRESENT = (rc() for x in [0...100]).join ''

  TIMERS = _.extend { workSec: 25 * 60, breakSec: 5 * 60 }, options?.timers

  mongoose.connect options?.db or 'mongodb://localhost/tomato'

  # tasks are individual line items in a tomato -- something to be accomplished
  TaskSchema = new mongoose.Schema
    id: String
    name: String
    order:
      type: Number
      default: 0
      min: -1e100
      max: 1e100
    createdAt: Date
    updatedAt: Date
    finishedAt: Date
    tomatoes: [
      startedAt: Date
      finishedAt: Date
    ]

  # breaks are just labeled segments of time
  BreakSchema = new mongoose.Schema
    startedAt: Date
    finishedAt: Date
    flavor: String

  # a tomato is pretty much a list of tasks and a list of breaks -- a todo list
  TomatoSchema = new mongoose.Schema
    slug:
      type: String
      unique: true
      trim: true
      match: /^[^\/]+$/
    workSec:
      type: Number
      min: 1
    breakSec:
      type: Number
      min: 1
    createdAt: Date
    updatedAt: Date
    tasks: [ TaskSchema ]
    breaks: [ BreakSchema ]

  Task = mongoose.model 'Task', TaskSchema
  Break = mongoose.model 'Break', BreakSchema
  Tomato = mongoose.model 'Tomato', TomatoSchema

  app = express.createServer()

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

  app.get '/desktop.js', desktop.createServer()

  # GET / -- create a new tomato
  app.get '/', (req, res) ->
    id = (rc() for x in [0...16]).join ''
    now = Date.now()
    tomato = slug: id, createdAt: now, updatedAt: now, tasks: []
    new Tomato(_.extend tomato, TIMERS).save (err) ->
      return res.send(err, 500) if err
      res.redirect "/#{id}"

  # TOMATO routes

  fetchTomato = (req, res, next) ->
    conditions = slug: req.param 'tomato'
    fields = ['slug', 'workSec', 'breakSec', 'updatedAt']
    Tomato.findOne conditions, fields, (err, tomato) ->
      return res.send(err, 500) if err
      return res.send(404) unless tomato
      res.locals tomato: tomato
      next()

  # GET /:tomato -- return the html to drive the client-side tomato app
  app.get '/:tomato', fetchTomato, (req, res) ->
    ctx =
      analytics: options?.analytics
      basepath: (app.settings.basepath or '').replace /\/$/, ''
    res.render 'main', ctx

  # PUT /:tomato -- update the id, name, etc. of a tomato
  app.put '/:tomato', fetchTomato, (req, res) ->
    tomato = res.local 'tomato'
    now = Date.now()
    for key in ['slug', 'workSec', 'breakSec']
      value = req.param key, NOTPRESENT
      if value isnt NOTPRESENT
        tomato.set key, value
        tomato.set 'updatedAt', now
    tomato.save (err) ->
      return res.send(err, 500) if err
      res.send 200

  # DELETE /:tomato -- delete a tomato and all tasks and breaks
  app.del '/:tomato', (req, res) ->
    Tomato.remove { slug: req.param 'tomato' }, (err) ->
      return res.send(err, 500) if err
      res.send 200

  # TASK routes

  fetchTasks = (req, res, next) ->
    conditions = slug: req.param 'tomato'
    fields = ['slug', 'updatedAt', 'tasks']
    Tomato.findOne conditions, fields, (err, tomato) ->
      return res.send(err, 500) if err
      return res.send(404) unless tomato
      res.locals tomato: tomato
      next()

  fetchTask = (req, res, next) ->
    id = req.param 'task'
    conditions = slug: req.param 'tomato'
    fields = ['slug', 'updatedAt', 'tasks']
    Tomato.findOne conditions, fields, (err, tomato) ->
      return res.send(err, 500) if err
      return res.send(404) unless tomato
      task = _.find tomato.tasks, (t) -> t.id is id
      return res.send(404) unless task?
      res.locals tomato: tomato, task: task
      next()

  # GET /:tomato/tasks -- get all tasks for a tomato
  app.get '/:tomato/tasks', fetchTasks, (req, res) ->
    res.send res.local('tomato').tasks

  # POST /:tomato/tasks -- create a new task for a tomato
  app.post '/:tomato/tasks', fetchTasks, (req, res) ->
    hash = (s) ->
      h = crypto.createHash 'md5'
      h.update s
      return h.digest 'hex'

    tomato = res.local 'tomato'
    name = req.param 'name'
    now = Date.now()
    task =
      id: hash "#{now}:#{name}"
      name: name
      order: req.param('order')
      createdAt: now
      updatedAt: now
      finishedAt: null
    tomato.tasks.push task
    tomato.set 'updatedAt', now
    tomato.save (err) ->
      return res.send(err, 500) if err
      res.send task

  # GET /:tomato/tasks/:task -- return data for a task
  app.get '/:tomato/tasks/:task', fetchTask, (req, res) ->
    res.send res.local 'task'

  # PUT /:tomato/tasks/:task -- update data for a task
  app.put '/:tomato/tasks/:task', fetchTask, (req, res) ->
    tomato = res.local 'tomato'
    task = res.local 'task'
    now = Date.now()
    for key in ['name', 'order', 'finishedAt', 'tomatoes']
      value = req.param key, NOTPRESENT
      if value isnt NOTPRESENT
        task.set key, value
        task.set 'updatedAt', now
        tomato.set 'updatedAt', now
    tomato.save (err) ->
      return res.send(err, 500) if err
      res.send 200

  # DELETE /:tomato/tasks/:task -- remove a task
  app.del '/:tomato/tasks/:task', fetchTasks, (req, res) ->
    tomato = res.local 'tomato'
    now = Date.now()
    index = _.indexOf _.pluck(tomato.tasks, 'id'), req.param 'task'
    tomato.tasks.splice index, 1
    tomato.set 'updatedAt', now
    tomato.save (err) ->
      return res.send(err, 500) if err
      res.send 200

  # BREAK routes

  fetchBreaks = (req, res, next) ->
    conditions = slug: req.param 'tomato'
    fields = ['slug', 'updatedAt', 'breaks']
    Tomato.findOne conditions, fields, (err, tomato) ->
      return res.send(err, 500) if err
      return res.send(404) unless tomato
      res.locals tomato: tomato
      next()

  fetchBreak = (req, res, next) ->
    id = req.param 'break'
    conditions = slug: req.param 'tomato'
    fields = ['slug', 'updatedAt', 'breaks']
    Tomato.findOne conditions, fields, (err, tomato) ->
      return res.send(err, 500) if err
      return res.send(404) unless tomato
      brake_ = _.find tomato.breaks, (t) -> t.id is id
      return res.send(404) unless brake
      res.locals tomato: tomato, break: brake
      next()

  # GET /:tomato/breaks -- get all breaks for a tomato
  app.get '/:tomato/breaks', fetchBreaks, (req, res) ->
    res.send res.local('tomato').breaks

  # POST /:tomato/breaks -- create a new break for a tomato
  app.post '/:tomato/breaks', fetchBreaks, (req, res) ->
    hash = (s) ->
      h = crypto.createHash 'md5'
      h.update s
      return h.digest 'hex'

  # GET /:tomato/breaks/:break -- return data for a break
  app.get '/:tomato/breaks/:break', fetchBreak, (req, res) ->
    res.send res.local 'break'

  # PUT /:tomato/breaks/:break -- update data for a break
  app.put '/:tomato/breaks/:break', fetchBreak, (req, res) ->
    tomato = res.local 'tomato'
    brake = res.local 'break'
    now = Date.now()
    for key in ['name', 'order', 'finishedAt', 'tomatoes']
      value = req.param key, NOTPRESENT
      if value isnt NOTPRESENT
        brake.set key, value
        brake.set 'updatedAt', now
        tomato.set 'updatedAt', now
    tomato.save (err) ->
      return res.send(err, 500) if err
      res.send 200

  # DELETE /:tomato/breaks/:break -- remove a break
  app.del '/:tomato/breaks/:break', fetchBreaks, (req, res) ->
    tomato = res.local 'tomato'
    now = Date.now()
    index = _.indexOf _.pluck(tomato.breaks, 'id'), req.param 'break'
    tomato.breaks.splice index, 1
    tomato.set 'updatedAt', now
    tomato.save (err) ->
      return res.send(err, 500) if err
      res.send 200

  return app


unless module.parent
  exports.middleware().listen 3000
  console.log 'tomato server listening on http://localhost:3000'
