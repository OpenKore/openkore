#!/usr/bin/env ruby
# Tool for creating a new unit test case.

require 'erb'

def main
	if ARGV.size != 1
		usage()
		exit 1
	end

	class_name = ARGV[0]
	if class_name !~ /^[a-z0-9]+$/i
		print "'#{class_name}' doesn't look like a valid class name.\n"
		exit 1
	end

	header = find_header(class_name)
	if header.nil?
		print "Cannot find header file for #{class_name}.\n"
		exit 1
	end

	source = generate_result(class_name, header)
	filename = File.join(File.dirname(__FILE__), "#{class_name}Test.cpp")
	if File.exist?(filename)
		print "Error: file #{class_name}Test.cpp already exists.\n"
		exit 1
	end

	f = File.new(filename, "w")
	f.print(source)
	f.close
	print "  Created     test/unit/#{class_name}Test.cpp\n"
end

def usage
	print "Usage: create.rb <CLASS>\n\n"
	print "Creates a new unit test case for CLASS.\n\n"
	print "Examples:\n"
	print "  create.rb Object\n"
	print "  create.rb InputStream\n"
end

def find_file(base_path, dirname, file)
	result = nil
	dir = Dir.open(dirname)
	dir.each do |entry|
		if entry =~ /^\./
			next
		elsif entry == file
			result = "#{base_path}/#{file}"
			break
		elsif File.directory?(File.join(dirname, entry))
			result = find_file("#{base_path}/#{entry}", File.join(dirname, entry), file)
			if !result.nil?
				break
			end
		end
	end
	dir.close
	return result
end

def find_header(class_name)
	dir = File.join(File.dirname(__FILE__), "..", "..")
	result = find_file(".", dir, "#{class_name}.h")
	if !result.nil?
		result = result.gsub(/^.\//, '')
	end
	return result
end

def generate_result(class_name, header)
	source = <<-EOF
		#include "tut.h"
		#include "../../#{header}"

		/*
		 * Test case for OSL::#{class_name}
		 */
		namespace tut {
			struct #{class_name}Test {
			};
		
			DEFINE_TEST_GROUP(#{class_name}Test);
		
			TEST_METHOD(1) {
				// Put your tests here.
				ensure(true);
			}
		}
EOF
	source = source.gsub(/^\t\t?/s, '')
	return source
end

main()
