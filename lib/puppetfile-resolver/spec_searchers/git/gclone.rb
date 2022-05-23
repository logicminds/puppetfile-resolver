# frozen_string_literal: true

require 'tempfile'
require 'English'
require 'puppetfile-resolver/util'
require 'puppetfile-resolver/spec_searchers/common'
require 'puppetfile-resolver/spec_searchers/git_configuration'
require 'uri'
module PuppetfileResolver
  module SpecSearchers
    module Git
      module GClone
        CLONE_CMD = 'git clone --bare --depth=1 --single-branch'
        # @summary clones the remote url and reads the metadata file
        # @returns [String] the content of the metadata file
        def self.metadata(puppetfile_module, resolver_ui, config)
          repo_url = puppetfile_module.remote

          return nil if repo_url.nil?
          return nil unless valid_http_url?(repo_url)
          metadata_file = 'metadata.json'

          ref = puppetfile_module.ref ||
                puppetfile_module.tag ||
                puppetfile_module.commit ||
                puppetfile_module.branch ||
                'HEAD'

          resolver_ui.debug { "Querying git repository #{repo_url}" }

          clone_and_read_file(repo_url, ref, metadata_file, config)
        end

        # @summary clones the git url and reads the file at the given ref
        #          a temp directory will be created and then destroyed during
        #          the cloning and reading process
        # @param ref [String] the git ref, branch, commit, tag
        # @param file [String] the file you wish to read
        # @returns [String] the content of the file
        def self.clone_and_read_file(url, ref, file, config)
          # cloning is a last resort if for some reason we cannot
          # remotely get via ls-remote
          Dir.mktmpdir do |dir|
            err_msg = ''
            proxy = ''
            if config.git.proxy
              err_msg += " with proxy #{config.git.proxy}: "
              proxy = "--config \"http.proxy=#{config.git.proxy}\" --config \"https.proxy=#{config.proxy}\""
            end
            branch = ref == 'HEAD' ? '' : "--branch=#{ref}"
            out, successful = run_command("#{CLONE_CMD} #{branch} #{url} #{dir} #{proxy}", silent: true)
            err_msg += out
            raise err_msg unless successful
            Dir.chdir(dir) do
              content, successful = run_command("git show #{ref}:#{file}")
              raise 'InvalidContent' unless successful && content.length > 2
              return content
            end
          end
        end

        # useful for mocking easily
        # @param cmd [String]
        # @param silent [Boolean] set to true if you wish to send output to /dev/null, false by default
        # @return [Array]
        def self.run_command(cmd, silent: false)
          out_args = silent ? '2>&1 > /dev/null' : '2>&1'
          out = `#{cmd} #{out_args}`
          [out, $CHILD_STATUS.success?]
        end

        def self.valid_http_url?(url)
          # uri does not work with git urls, return true
          return true if url.start_with?('git@')

          uri = URI.parse(url)
          uri.is_a?(URI::HTTP) && !uri.host.nil?
        rescue URI::InvalidURIError
          false
        end
      end
    end
  end
end
