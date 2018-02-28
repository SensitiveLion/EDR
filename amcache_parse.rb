require "csv"
require "optparse"
require "zip"
# require "pry"
@count = 1
options = {}
OptionParser.new do |opts|
  opts.on("-i", "--input name") do |i|
    options[:input] = i
  end

  opts.on("-o", "--output Directory") do |o|
    options[:output] = o
  end

  opts.on("-z", "--zip Name") do |b|
    options[:zip] = b
  end

  opts.on("-b", "--backup Directory") do |b|
    options[:backup] = b
  end
end.parse!

@output = options[:output]
@input = options[:input]
@zip = options[:zip]
@backup = options[:backup]
Zip::File.open("#{@input}/#{@zip}") do |zip_file|

  zip_file.glob('Amcache.hve') do |entry|
    @name = @zip.gsub(/edr_data_/,"")
    @name.gsub!(/_?\{.*/,"")
    if @name.empty?
      @name = "NONAME#{@count}"
      @count += 1
    end

    entry.extract("#{@input}/#{@name}_amcache")
    puts "Starting amcache parsing \n"

    amcache = `python amcache.py #{@input}/#{@name}_amcache`

    if amcache.empty?
      puts "error with amcache parser for #{@name} \n"
    else
      puts "Amcache parsed. Writing to #{@output}/amcache \n"
      CSV.open("#{@output}/amcache/#{@name}_amcache.csv", "w") do |csv|
        amcache.each_line do |l|
          l.chomp!
          csv << l.split("|")
        end
      end
      # end
      puts "#{@name} created in #{@output}/amcache directory \n"
    end
    if File.exist?("#{@input}/#{@name}_amcache") && @name.nil? == false
      File.delete("#{@input}/#{@name}_amcache")
    end
  end
end

if File.exist?("#{@input}/#{@zip}")
  File.rename("#{@input}/#{@zip}", "#{@backup}/#{@zip}")
end

