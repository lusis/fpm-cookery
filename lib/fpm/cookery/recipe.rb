require 'forwardable'
require 'fileutils'
require 'facter'
require 'fpm/cookery/source_handler'
require 'fpm/cookery/utils'
require 'fpm/cookery/path_helper'

module FPM
  module Cookery
    class Recipe
      include FileUtils
      include FPM::Cookery::Utils
      include FPM::Cookery::PathHelper

      def self.attr_rw(*attrs)
        attrs.each do |attr|
          class_eval %Q{
            def self.#{attr}(value = nil)
              value.nil? ? @#{attr} : @#{attr} = value
            end

            def #{attr}
              self.class.#{attr}
            end
          }
        end
      end

      def self.platforms(valid_platforms, &blk)
        p = []
        p.push(valid_platforms).flatten.member?(self.platform) ? (yield if block_given?) : false
      end

      def self.attr_rw_list(*attrs)
        attrs.each do |attr|
          class_eval %Q{
            def self.#{attr}(*list)
              @#{attr} ||= superclass.respond_to?(:#{attr}) ? superclass.#{attr} : []
              @#{attr} << list
              @#{attr}.flatten!
              @#{attr}.uniq!
              @#{attr}
            end

            def #{attr}
              self.class.#{attr}
            end
          }
        end
      end

      attr_rw :arch, :description, :homepage, :maintainer, :md5, :name,
              :revision, :section, :sha1, :sha256, :spec, :vendor, :version,
              :pre_install, :post_install, :pre_uninstall, :post_uninstall

      attr_rw_list :build_depends, :config_files, :conflicts, :depends,
                   :exclude, :patches, :provides, :replaces

      class << self
        def source(source = nil, spec = {})
          return @source if source.nil?
          @source = source
          @spec = spec
        end

        def platform
          Facter.fact(:operatingsystem).value.downcase.to_sym
        end
        alias_method :url, :source
      end

      def source
        self.class.source
      end

      def initialize(filename)
        @filename = Path.new(filename).expand_path
        @source_handler = SourceHandler.new(source, spec, cachedir, builddir)

        # Set some defaults.
        vendor || self.class.vendor('fpm')
        revision || self.class.revision(0)
      end

      attr_reader :filename, :source_handler

      extend Forwardable
      def_delegator :@source_handler, :local_path

      def workdir=(value)  @workdir  = Path.new(value) end
      def destdir=(value)  @destdir  = Path.new(value) end
      def builddir=(value) @builddir = Path.new(value) end
      def pkgdir=(value)   @pkgdir   = Path.new(value) end
      def cachedir=(value) @cachedir = Path.new(value) end

      def workdir(path = nil)  (@workdir  ||= filename.dirname)/path       end
      def destdir(path = nil)  (@destdir  ||= workdir('tmp-dest'))/path    end
      def builddir(path = nil) (@builddir ||= workdir('tmp-build'))/path   end
      def pkgdir(path = nil)   (@pkgdir   ||= workdir('pkg'))/path         end
      def cachedir(path = nil) (@cachedir ||= workdir('cache'))/path       end
    end
  end
end
