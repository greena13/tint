guard :rspec, cmd: "bundle exec rspec" do
  require "guard/rspec/dsl"
  dsl = Guard::RSpec::Dsl.new(self)

  last_run_spec = nil

  watch(%r{^lib/(.+)\.rb$}) do |match|
    file_path =
        if match[1] === 'lib'
          "spec/lib/#{match[2]}_spec.rb"
        else
          "spec/#{match[2]}_spec.rb"
        end

    if File.exists?(file_path)
      file_path
    else
      last_run_spec
    end
  end

  # RSpec files
  rspec = dsl.rspec
  watch(rspec.spec_helper) { rspec.spec_dir }
  watch(rspec.spec_support) { rspec.spec_dir }
  watch(rspec.spec_files) do |spec|
    last_run_spec = spec[0]
  end
end
