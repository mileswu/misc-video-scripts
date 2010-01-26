if RUBY_PLATFORM =~ /darwin/
	$LOAD_PATH << "lib/"
end
require 'wx'
require 'mkv2mp4'
include Wx
RowData = Struct.new(:path, :status)
$options[:verbose] = true
Thread.abort_on_exception = true

$gui = true

class LogCtrl < Wx::TextCtrl
	def puts(*v)
		self.append_text(v.join(""))
		self.append_text("\n")
	end
	def print(*v)
		self.append_text(v.join(""))
	end

end

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
	
	def del_selected
		for i in get_selections()
			delete_item(i)
		end
	end
end

class MyFrame < Wx::Frame
	attr_reader :progress
	def initialize
		$running = false
		super(nil, :title => "mkv2mp4-GUI", :pos => DEFAULT_POSITION, :size => [500,500])
		
		panel = Panel.new(self)
		
		@browseButton = Button.new(panel, ID_ANY, "Browse", [300, 0])
		evt_button(@browseButton.get_id()) {|event| browse }
		
		@startstopButton = Button.new(panel, ID_ANY, "Start", [300,50])
		evt_button(@startstopButton.get_id()) {|event| startstop }
		
		@listControl = FileList.new(panel, ID_ANY, :size => [200,200], :style => Wx::LC_REPORT | Wx::LC_VIRTUAL)		
	
		@delButton = Button.new(panel, ID_ANY, "Del", [400, 0])
		evt_button(@delButton.get_id()) {|event| @listControl.del_selected }
	
		@logControl = LogCtrl.new(panel, ID_ANY, :pos =>[0, 200], :size => [450,200], :style => TE_READONLY | TE_MULTILINE | TE_DONTWRAP)		
		$log = @logControl
		
		@progress = Gauge.new(panel, ID_ANY, 100, :pos =>[200, 100], :size => [150,20], :style => GA_HORIZONTAL | GA_SMOOTH)
		$progress = @progress
		
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
   
   def startstop
		if $running
			@thread.kill!
			Process.kill(9, $pid) if $pid
			$running = false
			@startstopButton.set_label("Start")
			item = @listControl.data.select {|a| a[:status] == "Running" }.first
			@listControl.change_state(@listControl.data.index(item), "Waiting") if item
		else
			$running = true
			@startstopButton.set_label("Stop")
			@thread = Thread.new do
				while(item = @listControl.data.select {|a| a[:status] == "Waiting" }.first)
					@listControl.change_state(@listControl.data.index(item), "Running")
					convert_file(item[:path])
					@listControl.change_state(@listControl.data.index(item), "Done")
				end
				$running = false
				@startstopButton.set_label("Start")
			end
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