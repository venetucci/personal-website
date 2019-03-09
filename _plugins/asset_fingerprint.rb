require 'digest'

module Jekyll
  # Jekyll assets asset_fingerprint filter
  module AssetFingerprint
    # Usage example:
    #
    # {{ "/style.css" | asset_fingerprint }}
    # {{ "/style.css" | asset_fingerprint | absolute_url }}
    def asset_fingerprint(relative_path)
      if Jekyll.env == "production"
        md5 = Digest::MD5.file(File.join(@context.registers[:site].dest, relative_path))
        interpolate_digest(relative_path, md5.hexdigest)
      else
        relative_path
      end
    rescue => exception
      puts exception
      relative_path
    end

    def interpolate_digest(path, digest)
      prefix, _, ext = path.rpartition('.')
      "#{prefix}-#{digest}.#{ext}"
    end
    module_function :interpolate_digest

  end
end

Liquid::Template.register_filter(Jekyll::AssetFingerprint)

Jekyll::Hooks.register :site, :post_write do |site|
  if Jekyll.env == "production"
    Dir.glob("#{site.config['destination']}/**/*.{js,css}").each do |file|
      md5 = Digest::MD5.file(file)
      FileUtils.cp(file, Jekyll::AssetFingerprint.interpolate_digest(file, md5.hexdigest))
    end
  end
end
