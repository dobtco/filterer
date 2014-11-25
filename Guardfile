guard :rspec, cmd: 'bundle exec rspec' do
  watch('spec/spec_helper.rb')                        { "spec" }

  watch(%r{^spec/.+_spec\.rb$})
  watch(%r{^app/(.+)\.rb$})                           { |m| "spec/#{m[1]}_spec.rb" }
  watch(%r{^app/(.*)(\.erb|\.haml|\.slim)$})          { |m| "spec/#{m[1]}#{m[2]}_spec.rb" }
  watch(%r{^app/models/filterer/(.+)\.rb$})        { |m| "app/models/filterer/#{m[1]}_spec.rb" }
  watch(%r{^lib/filterer/(.+)\.rb$})               { |m| "spec/lib/filterer/#{m[1]}_spec.rb" }
end
