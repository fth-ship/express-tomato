class exports.Tomato extends Backbone.Model
  validate: (attrs) ->
    return unless 'slug' of attrs
    return 'slug must be nonempty' unless attrs.slug.match /\S+/

  url: -> "/#{@id}"

  initialize: ->
    @id = @get 'slug'
