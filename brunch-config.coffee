exports.config =
  paths:
    public: __dirname
    watched: ['client']

  files:
    javascripts:
      joinTo:
        'client-build.js': /^client/

    templates:
      joinTo: 'client-build.js': /^client/

  modules:
    nameCleaner: (path) ->
      path.replace /^client/, 'cozy-clearance'

  overrides:

    production:
      sourceMaps: true

      files:
        javascripts:
          joinTo:
            'client-build.min.js': /^client/

        templates:
          joinTo: 'client-build.min.js': /^client/
