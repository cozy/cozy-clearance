
# npm install --save-dev gulp gulp-commonjs-wrap gulp-compile-js gulp-concat gulp-uglify
gulp = require 'gulp'
wrap = require 'gulp-commonjs-wrap'
compile = require 'gulp-compile-js'
concat = require 'gulp-concat'
uglify = require 'gulp-uglify'
# header = require 'gulp-header'
through = require 'gulp-commonjs-wrap/node_modules/through2'

version = require('./package.json').version

gulp.task 'buildclient', ->

    options =
        coffee:
            bare: true
        jade:
            client: true
            exports: true

    out = gulp.src('./client/*')
        .pipe compile options
        .pipe through.obj (file, enc, next) ->
            if file.isBuffer() and ~file.path.indexOf('template')
                content = file.contents.toString('utf8') + "\nmodule.exports = template;"
                file.contents = new Buffer content
            next null, file
        .pipe wrap
            pathModifier: (path) ->
                require('path').relative(__dirname, path)
                .replace('client', 'cozy-clearance')
                .replace('.js', '')

    out.pipe concat 'client-build.js'
    # .pipe header "// cozy-clearance #{version} client"
    .pipe gulp.dest './'

    out.pipe concat 'client-build.min.js'
    .pipe uglify()
    # .pipe header "// cozy-clearance #{version} client"
    .pipe gulp.dest './'

gulp.task 'default', ['buildclient']