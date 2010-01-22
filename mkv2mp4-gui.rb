require 'wx'
include Wx

class FileList < Wx::ListCtrl
	def initialize
		super
		insert_column(0, "name")
		
		@data = [{"name" => "a"}]
		set_item_count 1
	end
	
	def on_get_item_text(item, column)
		@data[item][column]
	end
end

class MyFrame < Wx::Frame
	def initialize
		super(nil, :title => "mkv2mp4-GUI", :pos => DEFAULT_POSITION, :size => DEFAULT_SIZE)
		
		panel = Panel.new(self)
		
		browseButton = Button.new(panel, ID_ANY, "Browse")
		evt_button(browseButton.get_id()) {|event| browse }
		
		startButton = Button.new(panel, ID_ANY, "Start")
		evt_button(browseButton.get_id()) {|event| start }
		
		listControl = FileList.new(panel, ID_ANY)
		
		
		show
	end
	
	def browse
		f = FileDialog.new(nil, "Choose files","", "", "*.mkv", FD_MULTIPLE)
		f.show_modal
		paths = f.get_paths
   end
end

class MinimalApp < App
   def on_init
       MyFrame.new()
   end
   
   
end
MinimalApp.new.main_loop