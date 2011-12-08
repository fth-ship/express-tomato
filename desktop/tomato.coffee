m = require('models/tomato')
c = require('collections/tasks')
v = require('views/app')

exports.initialize = (slug, workSec, breakSec) ->
  tomato = new m.Tomato(slug: slug, workSec: workSec, breakSec: breakSec)
  tasks = new c.Tasks()
  tasks.url = "/#{slug}/tasks"
  view = new v.App(model: tomato, collection: tasks)
  view.render()
  return tasks
