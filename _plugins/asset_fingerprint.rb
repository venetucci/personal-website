require 'digest'

module Jekyll
  # Jekyll assets asset_fingerprint filter
  module AssetFingerprint
    # Usage example:
    #
    # {{ "/style.css" | asset_fingerprint }}
    # {{ "/style.css" | asset_fingerprint | absolute_url }}
    def asset_fingerprint(path)
      AssetFingerprintGenerator.get_manifest_item(path) || path
    end
  end

  # Process assets as generators instead of converters so it can be done before template url interpolation.
  class AssetFingerprintGenerator < Generator
    @@manifest
    safe true

    def self.add_manifest_item(original_path, digest_path)
      @@manifest ||= {}
      @@manifest[original_path] = "/" + digest_path
    end

    def self.get_manifest_item(path)
      @@manifest[path] || @@manifest["/" + path]
    end

    def generate(site)
      Jekyll.logger.debug "Fingerprinting scss files"
      site.pages.each do |page|
        if page.name.end_with?('.scss')
          generate_scss(page, site)
        end
      end

      Jekyll.logger.debug "Fingerprinting static js files"
      site.static_files.each do |file|
        if file.name.end_with?('.js')
          generate_static(file, site)
        end
      end
    end

    private

    def generate_scss(file, site)
      Jekyll.logger.debug "Interpolating scss liquid vars"
      Jekyll::Renderer.new(site, file).run

      Jekyll.logger.debug "Generating css"
      content = site.find_converter_instance(
        Jekyll::Converters::Scss
      ).convert(file.content)

      Jekyll.logger.debug "Generating content digest"
      digest = Digest::MD5.hexdigest(file.content)
      filename = interpolate_digest(file.name, digest).gsub('.scss', '.css')

      Jekyll.logger.debug "Adding digest page"
      page = StaticFilePage.new(site, site.source, File.dirname(file.path), filename)
      page.content = content
      self.class.add_manifest_item("/" + file.relative_path.sub('scss', 'css'), page.relative_path)
      site.pages << page
    end

    def generate_static(file, site)
      src_path = File.join(site.source, file.relative_path)

      Jekyll.logger.debug "Generating content digest"
      digest = Digest::MD5.file(src_path)
      filename = interpolate_digest(file.name, digest)

      Jekyll.logger.debug "Adding digest page"
      page = StaticFilePage.new(site, site.source, File.dirname(file.relative_path), filename)
      page.content = File.read(src_path)
      self.class.add_manifest_item(file.relative_path, page.relative_path)
      site.pages << page
    end

    def interpolate_digest(path, digest)
      ext = File.extname(path)
      prefix = path[0..-ext.length - 1]
      "#{prefix}-#{digest}#{ext}"
    end
  end

  class StaticFilePage < Page
    def initialize(site, base, dir, name)
      @site = site
      @base = base
      @dir  = dir
      @name = name
      @data = { 'layout' => nil }

      self.process(@name)
    end
  end

end

Liquid::Template.register_filter(Jekyll::AssetFingerprint)
