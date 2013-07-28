# vim: sw=2 et

require 'json'
require 'open3'
require 'pathname'
require 'rest-client'
require 'stringio'

class Stcoveralls
  class JSONFileStringIO < StringIO
    def content_type
      'application/json'
    end
    def path
      'json_file'
    end
  end

  def self.coveralls
    c = self.new
    yield c if block_given?
    c.submit
  end

  def initialize
    @file_coverage = {}
    gather_project_info
    @include_git_info = true
  end

  attr_writer :include_git_info

  def gather_project_info
    project_info = {}
    if ENV['COVERALLS_REPO_TOKEN']
      project_info[:repo_token] = ENV['COVERALLS_REPO_TOKEN']
    elsif ENV['TRAVIS']
      project_info[:service_name] = 'travis-ci'
      project_info[:service_job_id] = ENV['TRAVIS_JOB_ID']
    end
    @project_info = project_info unless project_info.nil?
  end

  def can_submit?
    return true unless @project_info.fetch(:repo_token, "").empty?
    return true unless @project_info.fetch(:service_name, "").empty? || @project_info.fetch(:service_job_id, "").empty?
    false
  end

  def add_file_coverage(path, contents, coverage)
    @file_coverage[path] = [contents, coverage]
  end

  def add_stcoverage_local(coverage)
    cwd = Pathname.getwd
    cwds = cwd.to_s

    coverage.each do |k, v|
      next unless k.start_with? cwds

      path = Pathname.new k
      next unless path.file? && path.readable?

      relpath = path.relative_path_from cwd
      source = path.readlines
      sourcecoverage = Array.new(source.length) do |i|
        v.fetch(1+i, nil)
      end

      @file_coverage[relpath.to_s] = [source.join(''), sourcecoverage]
    end
  end

  def submit
    return false unless can_submit?

    coveralls_git = gitinfo if @include_git_info

    coveralls_data = {}
    coveralls_data.merge!(@project_info)
    coveralls_data[:git] = coveralls_git unless coveralls_git.nil?

    coveralls_source_files = []
    @file_coverage.each do |k, v|
      coveralls_source_files << {
        :name => k,
        :source => v[0],
        :coverage => v[1],
      }
    end
    coveralls_data[:source_files] = coveralls_source_files

    coveralls_json = JSON.generate(coveralls_data)

    json_file = JSONFileStringIO.new(coveralls_json, 'r')

    success = false
    RestClient.post 'https://coveralls.io/api/v1/jobs', { :json_file => json_file, :multipart => true } do |response, request, result|
      case response.code
      when 200
        success = true
      end
    end
    success
  end

  private

  def gitinfo
    gitinfo = { }

    gitinfohead = { }
    gitargs = [
      'log',
      '-n', '1',
      "--format=format:%H\n%ae\n%aN\n%ce\n%cN\n%s",
    ]
    Open3.popen3('git', *gitargs) do |stdin, stdout, stderr|
      [ :id, :author_email, :author_name, :committer_email, :committer_name, :message ].each do |x|
        value = stdout.gets
        value = value.chomp unless value.nil?
        gitinfohead[x] = value unless value.nil? or value.empty?
      end
    end
    gitinfo[:head] = gitinfohead unless gitinfohead.empty?

    gitbranch = nil
    Open3.popen3('git', *[ 'rev-parse', '--abbrev-ref=strict', 'HEAD' ]) do |stdin, stdout, stderr|
      value = stdout.gets
      value = value.chomp unless value.nil?
      gitbranch = value unless value.nil? or value.empty?
    end
    gitinfo[:branch] = gitbranch unless gitbranch.nil?

    gitinfo
  end
end
