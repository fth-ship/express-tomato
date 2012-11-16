controllers = require 'controllers'
directives = require 'directives'
filters = require 'filters'
services = require 'services'

Tomato = angular.module 'tomato', [
  'ngCookies'
  'ngResource'
  'tomato.controllers'
  'tomato.directives'
  'tomato.filters'
  'tomato.services'
]

exports.init = (basepath, slug) ->
  root = "#{basepath}/#{slug}/"

  Tomato.config [
    '$routeProvider'
    '$locationProvider'
    ($routeProvider, $locationProvider, config) ->
      $routeProvider
        .when(root, templateUrl: '/index.html', controller: 'TomatoCtrl')
        .when("#{root}/report", templateUrl: '/report.html', controller: 'ReportCtrl')
        .otherwise(redirectTo: root)
      $locationProvider.html5Mode true
  ]

  angular.element(document).ready ->
    angular.bootstrap document, ['tomato']
