if RUBY_PLATFORM =~ /darwin/
	$LOAD_PATH << "lib/"
end
require 'wx'
require 'mkv2mp4'
include Wx
RowData = Struct.new(:path, :status)
$options[:verbose] = true
Thread.abort_on_exception = true

class FileList < Wx::ListCtrl
	attr_reader :data
	def initialize(*args)
		@data = []

		super
		RowData.new.members.each_with_index do |name, index|
			insert_column(index, name.to_s)
		end
		
		set_item_count @data.length
	end
	
	def on_get_item_text(item, column)
		@data[item][column]
	end
	
	def change_state(item, status)
		@data[item][:status] = status
		refresh_item(item)
	end
	
	def add_item(item)
		@data << item
		set_item_count @data.length
	end
end

class MyFrame < Wx::Frame
	def initialize
		@running = false
		super(nil, :title => "mkv2mp4-GUI", :pos => DEFAULT_POSITION, :size => DEFAULT_SIZE)
		
		panel = Panel.new(self)
		
		@browseButton = Button.new(panel, ID_ANY, "Browse", [300, 0])
		evt_button(@browseButton.get_id()) {|event| browse }
		
		@startButton = Button.new(panel, ID_ANY, "Start", [300,50])
		evt_button(@startButton.get_id()) {|event| start }
		
		@listControl = FileList.new(panel, ID_ANY, :size => [200,200], :style => Wx::LC_REPORT | Wx::LC_VIRTUAL)		
		
		show
	end
	
	def browse
		f = FileDialog.new(nil, "Choose files","", "", "*.mkv", FD_MULTIPLE)
		f.show_modal
		paths = f.get_paths
		for i in paths
			@listControl.add_item(RowData.new(i, "Waiting"))
		end
   end
   
   def start
		return if @running
		@running = true
		@thread = Thread.new do
			while(item = @listControl.data.select {|a| a[:status] == "Waiting" }.first)
				@listControl.change_state(@listControl.data.index(item), "Running")
				convert_file(item[:path])
				@listControl.change_state(@listControl.data.index(item), "Done")
			end
			@running = false
		end
   end
end

class MinimalApp < App
   def on_init
		timer = Timer.new(self, ID_ANY)
		evt_timer(timer.id) {Thread.pass}
		timer.start(20)
       MyFrame.new()
   end
   
   
end
exit if defined?(Ocra)
MinimalApp.new.main_loop