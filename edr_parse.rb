#require "pry"
require "zip"
require "optparse"
require "csv"

options = {}
@log = []

OptionParser.new do |opts|
  opts.banner = "Usage: edr_parse.rb -i input_directory -o output_directory -b zip_backup_directory"

  opts.on("-i", "--input Directory") do |i|
    options[:input] = i
  end

  opts.on("-o", "--output Directory") do |o|
    options[:output] = o
  end

  opts.on("-b", "--backup Directory") do |b|
    options[:backup] = b
  end
end.parse!

def valid_zip?(file)
  zip = Zip::File.open(file)
  true
rescue StandardError
  false
ensure
  zip.close if zip
end

if options[:output] == nil and options[:input] == nil and options[:backup] == nil
  abort("specify path to EDR zip files using -i option, output path for parsed CSV files using -o option, and backup folder for zip files with -b option")
elsif options[:input] == nil
  abort("specify path to EDR zip files using -i option.")
elsif Dir.exist?(options[:input]) == false
  abort("input directory does not exist")
elsif options[:output] == nil
  abort("specify output path for parsed CSV files using -o option.")
elsif Dir.exist?(options[:output]) == false
  abort("output directory does not exist")
elsif options[:backup] == nil
  abort("specify backup folder for zip files with -b option.")
elsif Dir.exist?(options[:backup]) == false
  abort("backup directory does not exist")
else
  if Dir.exist?("#{options[:output]}/shimcache") == false
    `mkdir #{options[:output]}/shimcache`
  end
  if Dir.exist?("#{options[:output]}/objects") == false
    `mkdir #{options[:output]}/objects`
  end
  if Dir.exist?("#{options[:output]}/amcache") == false
    `mkdir #{options[:output]}/amcache`
  end

  while true
    @output = options[:output]
    @input = options[:input]
    @backup = options[:backup]
    zip_to_parse = Dir.entries(@input).grep(/\.zip/)
    if zip_to_parse.empty?
      puts "there are no files to parse in /#{@input}"
    elsif Dir.exist?(@input) == false
      puts "input directory does not exist"
    elsif Dir.exist?(@output) == false
      puts "output directory does not exist"
    else
      @amcache_zips = []
      @count = 0
      @files = zip_to_parse.count

      puts "#{@files} files left \n"
      zip_to_parse.each do |edr|
        if valid_zip?("#{@input}/#{edr}")
          Zip::File.open("#{@input}/#{edr}") do |zip_file|
            if zip_file.entries.count == 0
              empty = edr.gsub(/edr_data_/,"")
              empty.gsub!(/\{.*/,"")
              if empty.empty?
                empty = "NONAME#{@count}"
                @count += 1
              end
              open('zip_error.txt', 'a') { |f|
                f.puts empty
               }
              puts "#{empty} was empty \n"
              @log << "#{edr} was empty \n"
            elsif zip_file.glob('*SHIM.reg').count != 0||zip_file.glob('OBJECTS.DATA').count != 0||zip_file.glob('Amcache.hve').count != 0
              if zip_file.glob('*SHIM.reg').count != 0
                zip_file.glob('*SHIM.reg') do |entry|
                # Extract to file/directory/symlink
                  @name = "#{entry.name.chomp('-SHIM.reg')}__shim"
                  entry.extract("#{@input}/#{@name}")
                  puts "Starting ShimCache Parser \n"
                  shim = `python ShimCacheParser.py -r #{@input}/#{@name} -o #{@output}/shimcache/#{@name}.csv`
                  if /\[\+\] Writing output to/.match(shim)
                    puts "#{@name} created in #{@output}/shimcache directory \n"
                    @log << "#{@name} created in #{@output} directory \n"
                  else
                    open('error.txt', 'a') { |f|
                      f.puts entry.name.chomp('-SHIM.reg')
                    }
                    puts "#{entry.name.chomp('-SHIM.reg')} was missing shim and failed to create \n"
                    @log << "#{@name} created in #{@output} directory \n"
                  end
                  if File.exist?("#{@input}/#{@name}") && @name.nil? == false
                    File.delete("#{@input}/#{@name}")
                  end
                end
              end
              if zip_file.glob('OBJECTS.DATA').count != 0
                zip_file.glob('OBJECTS.DATA') do |entry|
                  @name = edr.gsub(/edr_data_/,"")
                  @name.gsub!(/\{.*/,"")
                  if @name.empty?
                    @name = "NONAME#{@count}"
                    @count += 1
                  end
                  entry.extract("#{@input}/OBJECTS.DATA")
                  puts "Starting OBJECTS.DATA Parser \n"

                  system("python CCM_RUA_Finder.py -i #{@input}/OBJECTS.DATA -o #{@input}/#{@name}.tsv")
                  if File.file?("#{@input}/#{@name}.tsv")
                    puts "OBJECTS.DATA parsed. Writing to #{@output}/objects \n"

                    CSV.open("#{@output}/objects/#{@name}.csv", "w") do |csv|
                       File.open("#{@input}/#{@name}.tsv") do |f|
                         f.each_line do|tsv|
                           tsv.chomp!
                           csv << tsv.encode('UTF-8', :invalid => :replace).split("\t")
                         end
                      end
                    end
                  else
                    puts "CCM_RUA_Finder.py failed to parse OBJECTS.DATA."
                  end
                  puts "#{@name} created in #{@output}/objects directory \n"
                  if File.exist?("#{@input}/#{@name}.tsv") && @name.nil? == false
                    File.delete("#{@input}/#{@name}.tsv")
                  end
                  if File.exist?("#{@input}/OBJECTS.DATA") && @name.nil? == false
                    File.delete("#{@input}/OBJECTS.DATA")
                  end
                end
              end
              if zip_file.glob('Amcache.hve').count != 0
                @amcache_zips << [@input,@output,edr,@backup]
              end
            else
              missing = edr.gsub(/edr_data_/,"")
              missing.gsub!(/\{.*/,"")
              if missing.empty?
                missing = "NONAME#{@count}"
                @count += 1
              end
              puts "#{missing} has no files to parse \n"
              @log << "#{edr} has no files to parse \n"
            end
          end


          @files -= 1
          puts "#{@files} files left \n"
        else
          corrupt = edr.gsub(/edr_data_/,"")
          corrupt.gsub!(/\{.*/,"")
          if corrupt.empty?
            corrupt = "NONAME#{@count}"
            @count += 1
          end
          open('zip_error.txt', 'a') { |f|
            f.puts corrupt
          }
          puts "#{corrupt} failed to open \n"
          @log << "#{corrupt} failed to open \n"
        end
      end
    end
    File.write("#{@output}/log.txt", @log.join)

    File.open("staging.txt", "w") do |f|
      @amcache_zips.each do |e|
        f << e.join("||")+"\n"
      end
    end

    system("ruby threading.rb")

    Dir["#{@input}/*.zip"].each do |file|
      zip_name = file.gsub(/#{@input}\//,'')
      File.rename("#{@input}/#{zip_name}", "#{@backup}/#{zip_name}")
    end

    File.write('staging.txt', '')

    sleep(3600)
  end
end
