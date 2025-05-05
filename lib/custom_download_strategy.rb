# lib/custom_download_strategy.rb
require "download_strategy"

# GitHubPrivateRepositoryReleaseDownloadStrategy downloads assets from GitHub
# private repositories. To use it, add
# `:download_strategy => GitHubPrivateRepositoryReleaseDownloadStrategy`
# to the URL section of your formula. This download strategy uses GitHub's
# API, so if you have a token in the environment it will use it.
class GitHubPrivateRepositoryReleaseDownloadStrategy < CurlDownloadStrategy
  require "utils/formatter"
  require "utils/github"

  def initialize(url, name, version, **meta)
    super
    parse_url_pattern
    set_github_token
  end

  def parse_url_pattern
    url_pattern = %r{https://github.com/([^/]+)/([^/]+)/releases/download/([^/]+)/(.+)}
    unless @url =~ url_pattern
      raise CurlDownloadStrategyError, "Invalid URL pattern for GitHub Repository."
    end

    _, @owner, @repo, @tag, @filename = *@url.match(url_pattern)
  end

  def download_url
    "https://api.github.com/repos/#{@owner}/#{@repo}/releases/assets/#{asset_id}"
  end

  def asset_id
    @asset_id ||= resolve_asset_id
  end

  def resolve_asset_id
    release_metadata = fetch_release_metadata
    assets = release_metadata["assets"].select { |a| a["name"] == @filename }
    raise CurlDownloadStrategyError, "Asset file not found." if assets.empty?

    assets.first["id"]
  end

  def fetch_release_metadata
    release_url = "https://api.github.com/repos/#{@owner}/#{@repo}/releases/tags/#{@tag}"
    GitHub::API.open_rest(release_url)
  end

  def set_github_token
    @github_token = ENV["HOMEBREW_GITHUB_API_TOKEN"] || GitHub::API.credentials
  end

  def _fetch(url:, resolved_url:, timeout:)
    # HTTP request header `Accept: application/octet-stream` is required.
    # Without this, the GitHub API will respond with metadata, not binary.
    curl_download 
      download_url,
      "--header", "Accept: application/octet-stream",
      "--header", "Authorization: token #{@github_token}",
      to: temporary_path
  end
end
