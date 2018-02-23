# require "pry"

@staging = []
def concurent
  @instances = 0
  process = `ps`
  processes = process.split(/\n/)

  processes.each do |p|
    if p.scan(/amcache_parse.rb/).empty? == false
      @instances += 1
    end
  end

  return @instances
end

File.open("staging.txt","r").each_line do |line|
  @staging << line.split("||")
end
if @staging.empty? == false
  @input = @staging.first[0]
  @output = @staging.first[1]
  @backup = @staging.first[3]

  while @staging.count != 0
    @temp = @staging.shift
    # if concurent < 5
      puts "Starting amcache parsing for #{@temp[2].chomp}\n"
      system("ruby amcache_parse.rb -i #{@temp[0]} -o #{@temp[1]} -z #{@temp[2]} -b #{@backup.chomp} &")
    # end
    sleep(5)
  end
end


