
# require 'sketchup.rb'
require 'matrix'
module ConsoleDeluxe

    def self.print_row(cols,spacings = [5,20,20,20,20,20,20])
      #spacings = [10,20,20,20,20,20,20]

      string_to_print = ""
      for i in 0..cols.length-1
        
        col_str = cols[i].to_s
        spacing =  spacings[i]
        
        spaces_to_add = [0,spacing - col_str.length].max
        if spaces_to_add < 0 then
          puts "AJAJAJAJ CONSOLE DELUXE IS BROKEN"
        end
        
        string_to_print = string_to_print + col_str + " "*spaces_to_add
      end
      
      puts string_to_print
    end

    def self.print_matrix(data,n_rows=4,n_cols=4)
      spacing = 10
      decimals = 2

      
      row_strings = Array.new(n_rows) {""}
      
      for col in 0...n_cols
        for row in 0...n_rows
          
          index = col*n_rows+row
          
          row_str = data[index].round(decimals).to_s
          spaces_to_add = [0,spacing - row_str.length].max
          
          if spaces_to_add < 0 then
            puts "AJAJAJAJ CONSOLE DELUXE IS BROKEN"
          end
          string_to_add = row_str + " "*spaces_to_add
          
          row_strings[row] += string_to_add 

        end
      end

      row_strings.each do |row_string| 
        puts row_string
      end
      return 0
    end

  class ConsoleTable
    def initialize(column_headings,spacings = [5,20],print_directly = false)
      @column_headings = column_headings
      @print_stack = Array.new

      #Pad spacings
      n_missing_spacings = column_headings.length - spacings.length
      if n_missing_spacings > 0 then
        @spacings = spacings.fill(spacings.last,spacings.length,n_missing_spacings)
      end

    end
    def add_row(cols)
      raise ArgumentError, 'Wrong number of collumns' unless cols.length = column_headings.length
      @print_stack.push(cols)
      

    end
    def make_row_string(cols,spacings)

      string_to_print = ""
      for i in 0..cols.length-1
        
        col_str = cols[i].to_s
        spacing =  spacings[i]
        
        spaces_to_add = [0,spacing - col_str.length].max
        if spaces_to_add < 0 then
          puts "AJAJAJAJ CONSOLE DELUXE IS BROKEN"
        end
        
        string_to_print = string_to_print + col_str + " "*spaces_to_add
      end
      
      puts string_to_print

    end
    def calculate_spacings_from_current_stack()
      padding = 2
      @spacings = @print_stack.transpose.collect{|x| x.collect{|y| y.length}.max+padding} #gets max of every collumn

    end
    
    
  end
     
end