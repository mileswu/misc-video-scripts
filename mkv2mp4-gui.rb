require 'wx'
include Wx

class MyFrame < Wx::Frame
	def initialize
		super(nil, :title => "mkv2mp4-GUI", :pos => DEFAULT_POSITION, :size => DEFAULT_SIZE)
		
		panel = Panel.new(self)
		
		browseButton = Button.new(panel, ID_ANY, "Browse")
		evt_button(browseButton.get_id()) {|event| browse }
		
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