TimerCtrl = ($scope, Work, Break) ->
  T = $scope.timer =
    clock: 0
    name: null
    work: null
    brake: null

  E = $('#timer')

  show = ->
    E.css top: '20%'
    E.modal('show').on 'hidden', ->
      E.css top: -1000
      Work.remove(workId: T.work.id, taskId: T.work.taskId) if T.work
      Break.remove(breakId: T.brake.id) if T.brake

  $scope.hide = ->
    E.modal('hide')
    E.css top: -1000

  $scope.finishBreak = ->
    T.brake.stoppedAt = moment.utc().format()
    T.brake.stoppedAtOffset = moment().zone()
    T.brake.$save breakId: T.brake.id, ->
      T.brake = null
      $scope.hide()

  $scope.$on 'start:work', (event, work) ->
    sec = 60 * $scope.tomato.workMin
    elapsed = moment.utc().diff moment.utc work.startedAt
    T.clock = sec - Math.floor elapsed / 1000
    T.work = work
    T.brake = null
    T.name = (t.name for t in $scope.tasks when t.id is work.taskId)[0]
    show()

  $scope.$on 'start:break', (event, brake) ->
    elapsed = moment.utc().diff moment.utc brake.startedAt
    T.clock = Math.max 1, Math.floor elapsed / 1000
    T.name = brake.name
    T.work = null
    T.brake = brake
    show()

  $scope.hide()

TimerCtrl.$inject = ['$scope', 'Work', 'Break']


TomatoCtrl = ($scope, $timeout, Tomato, Task, Work, Break) ->
  $scope.tomato = Tomato.get()
  $scope.tasks = Task.query()

  $scope.breaks = Break.query ->
    for brake in $scope.breaks
      continue if brake.stoppedAt > brake.startedAt
      $scope.$broadcast 'start:break', brake
      break

  $scope.works = Work.query ->
    earliest = moment.utc().subtract $scope.tomato.workMin, 'minutes'
    for work in $scope.works
      continue unless work.stoppedAt < work.startedAt
      cr = moment.utc work.startedAt
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
      url = "#{p}/#{encodeURIComponent $scope.tomato.slug}/"
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
      $scope.ui.task = new Task name: '', priority: 0, difficulty: 0
      $timeout $('#cr').select, 100

  $scope.startBreak = ->
    $scope.ui.brake.startedAt = moment.utc().format()
    $scope.ui.brake.startedAtOffset = moment().zone()
    Break.save $scope.ui.brake, (brake) ->
      $scope.ui.brake = new Break name: 'quick'
      $scope.$broadcast 'start:break', brake

  $('#cr').select()

TomatoCtrl.$inject = ['$scope', '$timeout', 'Tomato', 'Task', 'Work', 'Break']


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
    w = new Work
      startedAt: moment.utc().format()
      startedAtOffset: moment().zone()
    w.$save taskId: task.id, (w) ->
      $scope.$parent.$parent.$broadcast 'start:work', w

  $scope.remove = ->
    return if task.finishedAt > task.createdAt
    task.$remove taskId: task.id

  $scope.finish = ->
    if task.finishedAt <= task.createdAt
      task.finishedAt = moment()
    else
      task.finishedAt = moment(0)
    task.$save taskId: task.id

TaskCtrl.$inject = ['$scope', 'Work']


angular.module('app.controllers', ['app.services'])
  .controller('TomatoCtrl', TomatoCtrl)
  .controller('TaskCtrl', TaskCtrl)
  .controller('TimerCtrl', TimerCtrl)
