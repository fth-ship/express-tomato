TimerCtrl = ($scope, Work, Break) ->
  T = $scope.timer =
    clock: 0
    name: null
    work: null
    brake: null

  E = $('#timer')
  show = ->
    E.modal('show').on 'hidden', ->
      console.log T
      Work.remove(workId: T.work.id, taskId: T.work.taskId) if T.work
      Break.remove(breakId: T.brake.id) if T.brake

  $scope.finishBreak = ->
    T.brake.$save breakId: T.brake.id, ->
      T.brake = null
      E.modal('hide')

  $scope.$on 'start:work', (event, work) ->
    sec = 60 * $scope.tomato.workMin
    elapsed = new Date() - new Date work.createdAt
    T.clock = sec - Math.floor elapsed / 1000
    T.work = work
    T.brake = null
    T.name = (t.name for t in $scope.tasks when t.id is work.taskId)[0]
    show()

  $scope.$on 'start:break', (event, brake) ->
    elapsed = new Date() - new Date brake.createdAt
    T.clock = Math.max 1, Math.floor elapsed / 1000
    T.name = brake.name
    T.work = null
    T.brake = brake
    show()

TimerCtrl.$inject = ['$scope', 'Work', 'Break']


TomatoCtrl = ($scope, Tomato, Task, Work, Break) ->
  $scope.tomato = Tomato.get()
  $scope.tasks = Task.query()

  $scope.breaks = Break.query ->
    for brake in $scope.breaks
      continue if brake.updatedAt > brake.createdAt
      $scope.$broadcast 'start:break', brake
      break

  $scope.works = Work.query ->
    workMs = 60000 * $scope.tomato.workMin
    earliest = new Date().getTime() - workMs
    for work in $scope.works
      continue unless work.createdAt is work.updatedAt
      cr = new Date(work.createdAt).getTime()
      if cr < earliest
        work.$remove(workId: work.id, taskId: work.taskId)
      else
        $scope.$broadcast 'start:work', work
        break

  $scope.ui =
    filter: ''
    order: (t) -> "#{t.finishedAt}-#{9 - t.priority}-#{t.name}"
    edit: false
    task: new Task(name: '', priority: 0, difficulty: 0)
    brake: new Break(name: 'quick')

  $scope.edit = ->
    $scope.ui.edit = not $scope.ui.edit
    $timeout($('#slug').select, 100) if $scope.ui.edit

  $scope.update = ->
    Tomato.save $scope.tomato, (t) ->
      [_, p, _, s] = window.location.href.match /^(.+?)\/([^\/]+)\/(\#.+)$/
      url = "#{p}/#{$scope.tomato.slug}/"
      window.location.href = if s then "#{url}#{s}" else url
      $scope.ui.edit = false

  $scope.remove = ->
    Tomato.remove $scope.tomato, (t) ->
      [_, p, _, _] = window.location.href.match /^(.+?)\/([^\/]+)\/(\#.+)$/
      window.location.href = p

  $scope.addTask = ->
    return if $scope.ui.task.name is ''
    Task.save $scope.ui.task, (task) ->
      $scope.tasks.push task
      $scope.ui.task = new Task(name: '', priority: 0, difficulty: 0)
      $timeout($('#cr').select, 100)

  $scope.startBreak = ->
    Break.save $scope.ui.brake, (brake) ->
      $scope.ui.brake = new Break(name: 'quick')
      $scope.$broadcast 'start:break', brake

  $('#cr').select()

TomatoCtrl.$inject = ['$scope', 'Tomato', 'Task', 'Work', 'Break']


TaskCtrl = ($scope, Work) ->
  task = $scope.$parent.task

  $scope.works = ->
    (w for w in $scope.$parent.works when w.taskId is task.id)

  $scope.flag = ->
    return if task.finishedAt > task.createdAt
    task.priority = if task.priority is 0 then 1 else 0
    task.$save taskId: task.id

  $scope.start = ->
    return if task.finishedAt > task.createdAt
    task.$save taskId: task.id
    new Work().$save taskId: task.id, (w) ->
      $scope.$parent.$parent.$broadcast 'start:work', w

  $scope.remove = ->
    return if task.finishedAt > task.createdAt
    task.$remove taskId: task.id, -> $scope.$parent.$parent.tasks.splice i, 1

  $scope.finish = ->
    if task.finishedAt <= task.createdAt
      task.finishedAt = new Date()
    else
      task.finishedAt = new Date(0)
    task.$save taskId: task.id

TaskCtrl.$inject = ['$scope', 'Work']


angular.module('app.controllers', ['app.services'])
  .controller('TomatoCtrl', TomatoCtrl)
  .controller('TaskCtrl', TaskCtrl)
  .controller('TimerCtrl', TimerCtrl)
