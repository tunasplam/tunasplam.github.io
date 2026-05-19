require 'net/http'
require 'json'
require 'uri'
require 'cgi'

module Jekyll
  class WikipediaTag < Liquid::Tag
    @@cache = {}

    def initialize(tag_name, markup, tokens)
      super
      @markup = markup.strip
    end

    def parse_args(markup)
      # {% wikipedia "Title" %}  — title used as slug (spaces → underscores)
      if markup =~ /\A['"](.+)['"]\z/
        title = $1
        return { title: title, slug: title.gsub(' ', '_') }
      end

      # {% wikipedia title="Display Title" slug="Article_Slug" %}
      args = {}
      markup.scan(/(\w+)=["']([^"']+)["']/) { |k, v| args[k] = v }
      args['slug'] ||= args['title']&.gsub(' ', '_')
      args
    end

    def fetch_summary(slug)
      return @@cache[slug] if @@cache.key?(slug)

      encoded = URI.encode_www_form_component(slug)
      uri = URI("https://en.wikipedia.org/api/rest_v1/page/summary/#{encoded}")
      response = Net::HTTP.get_response(uri)

      @@cache[slug] =
        if response.is_a?(Net::HTTPSuccess)
          JSON.parse(response.body)['extract']
        end
    end

    def render(_context)
      args = parse_args(@markup)
      title = args['title'] || args[:title]
      slug  = args['slug']  || args[:slug]
      url   = "https://en.wikipedia.org/wiki/#{slug}"

      summary = fetch_summary(slug)
      content =
        if summary
          "<p>#{CGI.escapeHTML(summary)}</p>"
        else
          "<p><em>Could not fetch Wikipedia summary for \"#{CGI.escapeHTML(title)}\".</em></p>"
        end

      <<~HTML
        <div class="admonition admonition-wikipedia">
          <p class="admonition-title">
            <a href="#{url}" target="_blank" rel="noopener">#{CGI.escapeHTML(title)}</a>
          </p>
          <div class="admonition-content">
            #{content}
          </div>
        </div>
      HTML
    end
  end
end

Liquid::Template.register_tag('wikipedia', Jekyll::WikipediaTag)
