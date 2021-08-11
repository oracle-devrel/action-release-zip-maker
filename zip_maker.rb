# Copyright (c) 2021 Oracle and/or its affiliates.

require 'json'
require 'zip'
require 'httparty'

class String
  def to_bool
    if casecmp('Y').zero? || casecmp('true').zero? || casecmp('1').zero?
      true
    else
      false
    end
  end
  
  def get_tag
    match = /^\w+\/\w+\/(.*)$/.match(self)
    if !match.nil? && match.length == 2
      match[1]
    end
  end
end

def get_env_vars()
  required_vars = ['GITHUB_REF', 'INPUT_GITHUB_TOKEN', 'GITHUB_REPOSITORY']
  required_vars.each do |v|
    if ENV.include?(v) && ENV[v].to_s.length > 0
      self.instance_variable_set("@#{v.downcase}", ENV[v])
    end
  end
  # validate they're all present and accounted for...
  required_vars.each do |v|
    if self.instance_variable_get("@#{v.downcase}").nil? || self.instance_variable_get("@#{v.downcase}").length <= 0
      puts "ERROR - MISSING REQUIRED ENV VARIABLE: #{v}"
      exit 1
    end
  end
  
  optional_vars = []
  optional_vars.each do |v|
    if ENV.include?(v) && ENV[v].to_s.length > 0
      self.instance_variable_set("@#{v.downcase}", ENV[v])
    end
  end
  
end

def get_release_by_tag(in_repo, in_tag)
  ret = JSON.parse('[]')
  
  headers = {
    'Content-Type' => 'application/vnd.github.v3+json',
    'Authorization' => "token #{@input_github_token}"
  }
  url = "https://api.github.com/repos/#{in_repo}/releases/tags/#{in_tag}"
  resp = HTTParty.get(url, headers: headers)
  
  ret = JSON.parse(resp.body)
  
  ret
end

def upload_to_release(in_repo, release_id, zip_file)
  ret = false
  
  options = {
    headers: {
      'Content-Type' => 'application/zip',
      'Authorization' => "token #{@input_github_token}",
      'Content-Length' => File.size(zip_file).to_s
    },
    body: IO.read(zip_file, mode: 'rb'),
    query: {
      'name' => zip_file
    }
  }
  url = "https://uploads.github.com/repos/#{in_repo}/releases/#{release_id}/assets"
  resp = HTTParty.post(url, options)
  
  if resp.code == 201
    ret = true
  else
    puts "ERROR:\nmessage: #{resp.message}, code: #{resp.code}, body: #{resp.body}"
    exit 1
  end
  
  ret
end

def exclude?(in_file, in_excludes)
  ret = false
  
  if !in_file.nil? && in_file.to_s.length > 0 && !in_excludes.nil? && in_excludes.class == Array && in_excludes.count > 0
    in_excludes.each do |exclude|
      Dir.glob(exclude).each do |real_exclude|
        if in_file.casecmp(real_exclude) == 0
          ret = true
          break
        end
      end
    end
  end
  
  ret
end

def element_present?(list, entry)
  ret = false
  
  if list.include?(entry) && !list[entry].nil?
    ret = true
  end
  
  ret
end

def add_file(src, dst, zipfile)
  src_file = File.expand_path(src)
  # remove leading . and /
  if File.dirname(dst).split('/')[0] == '.'
    dirs = File.dirname(dst).split('/')
    dst_file = File.join(dirs[1..dirs.length], File.basename(dst))
    dst_file = dst_file[1..dst_file.length] if dst_file[0] == '/'
  else
    dst_file = dst
  end
  
  puts "adding file #{src} as #{dst_file}"
  if File.exist?(src_file)
    zipfile.add(dst_file, src_file)
  else
    @missing_files << src
  end
end

def add_dir(src, dst, recursive, zipfile)
  src_dir = File.expand_path(src)
  
  if Dir.exist?(src_dir)
    zipfile.mkdir(dst)
    
    Dir.each_child(src_dir) do |x|
      entry_file = File.join(src_dir, x)
      if File.directory?(entry_file)
        add_dir(entry_file, entry_file, zipfile)
      elsif File.file?(entry_file)
        add_file(entry_file, File.join(src, x), zipfile)
      end
    end
  else
    @missing_files << src
  end
end

@cfg_file = 'release_files.json'
@zip_files = []
@missing_files = []
@fail_on_missing_file = false
@overwrite_dst = true

if ARGV[0].to_s.length > 0
  @cfg_file = ARGV[0]
end

if ENV.include?('INPUT_CONFIG_FILE') && ENV['INPUT_CONFIG_FILE'].to_s.length > 0
  @cfg_file = ENV['INPUT_CONFIG_FILE']
end

if ENV.include?('INPUT_FAIL_ON_MISSING_FILE') && ENV['INPUT_FAIL_ON_MISSING_FILE'].to_s.length > 0
  @fail_on_missing_file = ENV['INPUT_FAIL_ON_MISSING_FILE'].to_s.to_bool
end

if ENV.include?('INPUT_OVERWRITE_DST') && ENV['INPUT_OVERWRITE_DST'].to_s.length > 0
  @overwrite_dst = ENV['INPUT_OVERWRITE_DST'].to_s.to_bool
end

config = JSON.parse(File.read(@cfg_file))
config.each do |cfg_entry|
  if cfg_entry['action'] == 'create_zip'
    dst_zip_file = cfg_entry['file_name']
    @zip_files << dst_zip_file
    
    if @overwrite_dst
      File.delete(dst_zip_file) if File.exist?(dst_zip_file)
    end
    
    Zip::File.open(dst_zip_file, create: true) do |zipfile|
      cfg_entry['files'].each do |file_entry|
        recursive = true
        recursive = file_entry['recursive'].to_s.to_bool if element_present?(file_entry, recursive)
        
        # is it a static file/dir?
        if element_present?(file_entry, 'src')
          src_file = file_entry['src']
          # diff name in ZIP?
          if element_present?(file_entry, 'dst')
            dst_file = file_entry['dst']
            
            if File.directory?(src_file)
              add_dir(src_file, dst_file, recursive, zipfile)
            elsif File.file?(src_file)
              add_file(src_file, dst_file, zipfile)
            else
              @missing_files << src_file
            end
          # no dest - use original name
          else
            if File.directory?(src_file)
              add_dir(src_file, src_file, recursive, zipfile)
            elsif File.file?(src_file)
              add_file(src_file, src_file, zipfile)
            else
              @missing_files << src_file
            end
          end
        # pattern?
        elsif element_present?(file_entry, 'src_pattern')
          Dir.glob(file_entry['src_pattern']) do |src_file|
            exclude = file_entry.include?('exclude') && exclude?(src_file, file_entry['exclude']) ? true : false
            
            if !exclude
              dst_file = src_file
              if element_present?(file_entry, 'dst_path')
                split_file = dst_file.split('/')
                dst_file = split_file[1..split_file.length].join('/')
                dst_file = File.join(file_entry['dst_path'], dst_file)
              end
              
              if File.directory?(src_file)
                add_dir(src_file, dst_file, recursive, zipfile)
              elsif File.file?(src_file)
                add_file(src_file, dst_file, zipfile)
              else
                @missing_files << src_file
              end
            else
              puts "excluding #{src_file}"
            end
          end
        end
      end
    end
  elsif cfg_entry['action'] == 'upload_file'
    get_env_vars()
    release = get_release_by_tag(@github_repository, @github_ref.get_tag)
    release_id = release['id']
    upload_to_release(@github_repository, release_id, cfg_entry['file_name'])
  end
end

puts "zip_files: #{@zip_files.to_json}"
puts "::set-output name=zip_files::#{@zip_files.to_json}"

puts "missing_files: #{@missing_files.to_json}"
puts "::set-output name=missing_files::#{@missing_files.to_json}"

if @fail_on_missing_file && @missing_files.count > 0
  exit 1
end