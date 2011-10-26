class Column
  def initialize
    @name = ""
    @data_type = ""
    @related_to = ""
    @access_path = ""
    @type = ""
  end
  attr_accessor(:name,:data_type,:related_to,:access_path,:type)

  # If there is an access path on foreign key, the method returns it.
  def examine_fk()
    if @type == "foreign_key"
      if @access_path.length > 0
        return @access_path, @related_to
      else
        return nil
      end
    else
      return nil
    end
  end

# Performs case analysis with respect to the column_data type (class value)
# and fills the variables with necessary values.
  def bind_datatypes(sqlite3_type, column_cast, sqlite3_parameters, 
                     column_cast_back, access_path)
    if @data_type == "int" || 
        @data_type == "integer" ||
        @data_type == "tinyint" ||
        @data_type == "smallint"||
        @data_type == "mediumint" ||
        @data_type == "bigint" ||
        @data_type == "unsigned bigint" ||
        @data_type == "int2" ||
        @data_type == "bool" || 
        @data_type == "boolean" ||
        @data_type == "int8" || 
        @data_type == "numeric"
      sqlite3_type.replace("int")
    elsif @data_type == "blob"
      sqlite3_type = "blob"
      column_cast.replace("(const void *)")
      sqlite3_parameters.replace(", -1, SQLITE_STATIC")
    elsif @data_type == "float" ||
        @data_type == "double"  ||
        @data_type.match(/decimal/i) ||
        @data_type == "double precision" ||
        @data_type == "real"
      sqlite3_type.replace("double")
    elsif @data_type == "text" || 
        @data_type == "date" ||
        @data_type == "datetime" ||
        @data_type.match(/character/i) ||
        @data_type.match(/varchar/i) ||
        @data_type.match(/nvarchar/i) ||
        @data_type.match(/varying character/i) ||
        @data_type.match(/native character/i) ||
        @data_type == "clob" ||
        @data_type.match(/nchar/i)
      sqlite3_type.replace("text")
      column_cast.replace("(const unsigned char *)")
      sqlite3_parameters.replace(", -1, SQLITE_STATIC")
    elsif @data_type == "string"
      sqlite3_type.replace("text")
      column_cast.replace("(const unsigned char *)")
      column_cast_back.replace(".c_str()")
      sqlite3_parameters.replace(", -1, SQLITE_STATIC")
    elsif @data_type == "references"
      # needs taken care of
      sqlite3_type.replace("int")
      column_cast.replace("(long int)&")
    end
    access_path.replace(@access_path)
=begin
    if column_cast == nil
      column_cast = ""
    end
    if sqlite3_parameters == nil
      sqlite3_parameters = ""
    end
    if column_cast_back == nil
      column_cast_back = ""
    end
=end
  end

# Validates a column data type
# The following data types are the ones accepted by sqlite.
  def verify_data_type(data_type)
    dt = data_type.downcase
    if dt == "int" ||
        dt == "integer" ||
        dt == "tinyint" ||
        dt == "smallint" ||
        dt == "mediumint" ||
        dt == "bigint" ||
        dt == "unsigned bigint" ||
        dt == "int2" ||
        dt == "int8" ||
        dt == "blob" ||
        dt == "float" ||
        dt == "double"  ||
        dt == "double precision" ||
        dt == "real" ||
        dt == "numeric" ||
        dt == "date" ||
        dt == "bool" ||
        dt == "boolean" ||
        dt == "datetime" ||
        dt.match(/\idecimal/) ||
        dt == "text" ||
        dt == "clob" ||
        dt.match(/character/i) ||
        dt.match(/varchar/i) ||
        dt.match(/nvarchar/i) ||
        dt.match(/varying character/i) ||
        dt.match(/native character/i) ||
        dt.match(/nchar/i) ||
        dt.match(/char/i)
      return dt
    elsif dt == "string"
      return "text"
    else
      puts $err_state
      raise TypeError.new("no such data type " + data_type.upcase + "\n")
    end
  end


# @type +: cast, backpointer after foreign_key
# Matches each column description against a pattern and extracts 
# column traits.
  def set(column)
    pattern = Regexp.new(/(\w+) (\w+)(\s*)from(\s*)&(\w*)(\s*)(\S*)|(\w+) (\w+)(\s*)from(\s*)(\S+)/i)
    count_primitive = 0
    column.lstrip!
    column.rstrip!
    if column.match(/&\w/)
      @type = "foreign_key"
    elsif column.match(/&\s|&/)
      @type = "primary_key"
    end
    if column.match(/self/i)
      @type += "primitive"
      count_primitive += 1
    end
    if @type.length == 0
      @type = "standard"
    end
    matchdata = pattern.match(column)
    column_data = Array.new
    l = 0
    cd = 0
    if matchdata
      while l < matchdata.length
        if matchdata[l] != nil
          column_data[cd] = matchdata[l]
          # strip whitespace from front and back
          column_data[cd].lstrip!
          column_data[cd].rstrip!
          if column_data[cd].length == 0
            column_data.delete_at(cd)
            cd -= 1
          end        
          puts "column_data[" + cd.to_s + "] = " + column_data[cd]
          cd += 1
        end
        l += 1
      end
      @name = column_data[1]
      @data_type = verify_data_type(column_data[2])
      if column_data.length == 5
        @related_to = column_data[3]
        @access_path = column_data[4]
        if @access_path.match(/\$/)
          puts "$"
          @access_path.gsub!(/\$/,".")
        end
      elsif column_data.length == 4
        if @type == "foreign_key"
          @related_to = column_data[3]
        else
# if @type == "primary_key" or @type not key(!&) but data column then..
          @access_path = column_data[3]
        end
      elsif column_data.length == 3
      else
        puts "Invalid format.\n"  
      end
      puts "Column name is: " + @name
      puts "Column data type is: " + @data_type
      puts "Column related to: " + @related_to
      puts "Column access path is: " + @access_path
      puts "Column type is: " + @type
    else
      puts "Invalid format. One or more of identifiers 'FROM''(space)' missing\n"
      exit(1)
    end
    return count_primitive
  end
  
# Returns valid column format for use in VT create queries.
  def print_col_info()
#    puts "type is " + @type
    if @type == "primary_key"
      return @name + " INTEGER PRIMARY KEY"
    elsif @type == "foreign_key"
      return @name + " REFERENCES " + @related_to 
    elsif @type == "standard" || @type == "primitive"
      return @name + " " + @data_type
    else
      puts "Unrecognised state\n"
      exit(1)
    end
  end

end

class Data_structure_characteristics
  def initialize
    @name = ""
    @db = ""
    # content: map<string,Truck*>
    @signature = ""
    @stl_class = ""
    @object_class = ""
    @inherits = ""
# not needed. Always a pointer since we receive its address
#    @type = ""
# templatex_type: -1-nested, 1-pointer(not needed maybe), 2-primitive, 3-both
    @template1_type = 0
    @template2_type = 0
    @template1_name = ""
    @template2_name = ""
    @template_args = ""
    @parent = ""
#    @access = ""
    @columns = Array.new
    @s = "        "
  end
  attr_accessor(:name,:db,:signature,:stl_class,:object_class,:inherits,:type,:template1_type,:template2_type,:template1_name,:template2_name,:template_args,:parent,:access,:columns,:s)

  def print_cast(fw, cast, op_sign, op_relationship, access_path)
    if op_relationship == "standard"
      if op_sign == "stl"
        fw.puts "    " + cast +
          " *any_dstr = (" + cast + " *)stl->data;"
        fw.puts "    " + cast + ":: iterator iter;"
      elsif op_sign == "object"
        # maybe need to chomp possible '*'
        fw.puts "    " + cast +
          " *any_dstr = (" + cast + " *)stl->data;"
      else
        puts "ERROR: op_sign"
        exit(1)
      end
    elsif op_relationship == "cast"
      if op_sign == "stl"
        fw.puts "    " + cast +
          " *any_dstr = (" + cast + " *)stl->data;"
        fw.puts "    " + @signature +
          " *any_dstr = (" + @signature + " *)any_dstr->" + 
          access_path + ";"
        fw.puts "    " + @signature + ":: iterator iter;"
      elsif op_sign == "object"
        # maybe need to chomp possible '*'
        fw.puts "    " + cast +
          " *any_dstr = (" + cast + " *)stl->data;"
        fw.puts "    " + @object_class +
          " *any_dstr = (" + @object_class + " *)any_dstr->" +
          access_path + ";"
      else
        puts "ERROR: op_sign"
        exit(1)
      end
    elsif @object_class.match(/^relationship_table/i)
      # op_sign needless
      if op_sign == "stl"
        fw.puts "    " + cast +
          " *any_dstr = (" + cast + " *)stl->data;"
        fw.puts "    " + op_relationship +
          " *any_dstr = (" + op_relationship + " *)any_dstr->" + 
          access_path + ";"
      elsif op_sign == "object"
        # maybe need to chomp possible '*'
        fw.puts "    " + cast +
          " *any_dstr = (" + cast + " *)stl->data;"
        fw.puts "    " + op_relationship +
          " *any_dstr = (" + op_relationship + " *)any_dstr->" +
          access_path + ";"
      end
    else
      puts "ERROR: op_relationship"
      exit(1)
    end
  end

  # Invokes 'examine_fk' method for each column of the virtual table and 
  # returns the return value.
  def traverse_columns(path, related_to)
    col = 0
    p = 0
    while col < @columns.length
      # when pk?never access path?
      tmp_path, tmp_rel = @columns[col].examine_fk()
      if tmp_path != nil
        path[p] = ""
        path[p].replace(tmp_path)
        related_to[p] = ""
        related_to[p].replace(tmp_rel)
        p += 1
      end
      col += 1
    end
  end

  def examine_sign(parent_name)
    if @name == parent_name
      if @signature.length > 0
        return @signature, "stl"
      elsif @object_class.length > 0
        return @object_class, "object"
      else
        puts "ERROR: unspecified signature"
        exit(1)
      end
    else
      return nil, nil
    end
  end

# relationship table obsolete
  # Manages the casts on entrance of the virtual tables search and 
  # retrieve methods. If access path is nil then the standard cast is
  # performed, the backpointer in the stl->data is cast to the entity
  # represented by the virtual table.
  # If access path is not nil, the method helps prepare an explicit cast 
  # from the 
  # type of the parent virtual table, carried by the backpointer, to 
  # the type of the current virtual table.
  def manage_casts(fw, ds_array)
    cast = nil
    op_sign = nil
    access_path = Array.new
    related_to = Array.new
    traverse_columns(access_path, related_to)
    if @object_class.match(/^relationship_table/i)
      ds = 0
      while ds < ds_array.length && cast == nil
        curr_ds = ds_array[ds]
        cast, op_sign = curr_ds.examine_sign(@parent)
        ds += 1
      end
      if cast == nil
        puts "ERROR: Relationship not recorded"
        exit(1)
      end
      # Need to cast to the parent VT which does not have an access path.
      # The fk column of the relationship with the access path matches the 
      # child VT and will pass the address to it via backpointer.
      # child_signature holds the signature of the child VT that 
      # participates in the relationship.
      if access_path.length == 1
        ds = 0
        child_signature = nil
        while ds < ds_array.length && child_signature == nil
          curr_ds = ds_array[ds]
          child_signature, useless = curr_ds.examine_sign(related_to[0])
          ds += 1
        end
        if child_signature == nil
          puts "ERROR: RELATIONSHIP not recorded"
          exit(1)
        end
        print_cast(fw, cast, op_sign, child_signature, access_path[0])
      else
        puts "Unknown format of RELATIONSHIP_TABLE"
        exit(1)
      end
    else
      rt = 0
      stop = nil
      while rt < related_to.length && !stop
        puts "STOP"
        op_relationship = "cast"
        if related_to[rt] == @parent
          stop = true
        end
        rt += 1
      end
      # if an access path in fk has been found and the related_to table 
      # matches the parent table
      if stop
        puts "!STOP"
        ds = 0
        while ds < ds_array.length && cast == nil
          curr_ds = ds_array[ds]
          cast, op_sign = curr_ds.examine_sign(@parent)
          ds += 1
        end
        if cast == nil
          puts "ERROR: relationship not recorded"
          exit(1)
        end
      else
        op_relationship = "standard"
        if @signature.length > 0
          cast = @signature
          op_sign = "stl"
        else
          cast = @object_class
          op_sign = "object"
        end
      end
      print_cast(fw, cast, op_sign, op_relationship, access_path[rt])
    end
  end

  def retrieve_columns(fw)
    col = 0
    while col < @columns.length
      fw.puts "    case " + col.to_s + ":"
      sqlite3_type = ""
      column_cast = ""
      sqlite3_parameters = ""
      column_cast_back = ""
      access_path = ""
      @columns[col].bind_datatypes(sqlite3_type, column_cast, 
                                   sqlite3_parameters, column_cast_back, 
                                   access_path)
      if @signature.length > 0
        if access_path.length == 0
          iden = "(*iter)"
        else
          iden = "(*iter)."
        end
      else
        if access_path.length == 0
          iden = "any_dstr"
        else
          iden = "any_dstr->"
        end
      end
# too little exception in bind_datatypes to spoil code reuse
      if column_cast_back == ".c_str()"
        column_cast = "(const char *)"
      end
      fw.puts @s + "sqlite3_result_" + sqlite3_type + "(con, " + 
        column_cast + iden + access_path + column_cast_back + 
        sqlite3_parameters + ");"
      fw.puts @s + "break;"
      col += 1
    end
  end

# Generates code in retrieve method. Code makes the necessary arrangements 
# for retrieve to happen successfully (condition checks, reallocation)
  def setup_retrieve(fw, ds_array)

    #HereDoc1

        auto_gen5 = <<-AG5
    char *colName = stl->azColumn[n];
    int index = stcsr->current;
// iterator implementation. serial traversing or hit?
    iter = any_dstr->begin();
// serial traversing. simple and generic. visitor pattern is next step.
    for(int i=0; i<stcsr->resultSet[index]; i++){
        iter++;
    }
AG5

    fw.puts "    sqlite3_vtab_cursor *cur = (sqlite3_vtab_cursor *)stc;\
"
    fw.puts "    stlTable *stl = (stlTable *)cur->pVtab;"
    fw.puts "    stlTableCursor *stcsr = (stlTableCursor *)stc;"
    manage_casts(fw, ds_array)
    if @signature.length > 0
      fw.puts auto_gen5
    else
      fw.puts "    char *colName = stl->azColumn[n];"
    end
    fw.puts "    switch( n ){"
  end

# Generates code to search each VT struct.
# Each search case matches a specific column of the VT.
  def search_columns(fw)
    col = 0
    while col < @columns.length
      fw.puts @s + "case " + col.to_s + ":"
# if collection/map...
      if @signature.length > 0
        fw.puts @s + "    iter = any_dstr->begin();"
        fw.puts @s + "    for(int i=0; i<(int)any_dstr->size();i++){"
      end
      sqlite3_type = ""
      column_cast = ""
      sqlite3_parameters = ""
      column_cast_back = ""
      access_path = ""
      @columns[col].bind_datatypes(sqlite3_type, column_cast, 
                                   sqlite3_parameters, column_cast_back, 
                                   access_path)
      if @signature.length > 0
        if access_path.length == 0
          iden = "(*iter)"
        else
          iden = "(*iter)."
        end
      else
        if access_path.length == 0
          iden = "any_dstr"
        else
          iden = "any_dstr->"
        end
      end
      #      puts "sqlite3_type: " + sqlite3_type
      #      puts "column_cast: " + column_cast
      #      puts "sqlite3_parameters: " + sqlite3_parameters
      #      puts "column_cast_back: " + column_cast_back
      #      puts "access_path: " + access_path
      if @signature.length > 0
        fw.puts @s + @s + "if (traverse(" + column_cast + iden + 
          access_path + column_cast_back + ", op, sqlite3_value_" + 
          sqlite3_type + "(val)) )"
        fw.puts @s + @s + "    stcsr->resultSet[count++] = i;"
        fw.puts @s + @s + "iter++;"
        fw.puts @s + "    }"
      else
        fw.puts @s + "    if (traverse(" + column_cast + iden + 
          access_path + column_cast_back + ", op, sqlite3_value_" + 
          sqlite3_type + "(val)) )"
        fw.puts @s + @s + "stcsr->resultSet[count++] = i;"        
      end
      fw.puts @s + "    stcsr->size += count;"
      fw.puts @s + "    break;"
      col += 1
    end
  end

# Generates code in search method. Code makes the necessary arrangements 
# for search to happen successfully (condition checks, reallocation)
  def setup_search(fw, ds_array)

    #HereDoc1

  top_level = <<-tpl
        for (int j=0; j<get_datastructure_size((void *)stl); j++){
            stcsr->resultSet[j] = j;
            stcsr->size++;
	}
        assert(stcsr->size <= stcsr->max_size);
        assert(&stcsr->resultSet[stcsr->size] <= &stcsr->resultSet[stcsr->max_size]);

tpl


    #HereDoc2

  exit_search = <<-exs
        printf("embedded data structure cannot be requested constraint-less.must be joined");
        exit(1);
exs


    #HereDoc3

          auto_gen35 = <<-AG35
    }else{
        switch( constr[0] - 'A' ){
        case 0:
            op = 0;
            break;
        case 1:
            op = 1;
            break;
        case 2:
            op = 2;
            break;
        case 3:
            op = 3;
            break;
        case 4:
            op = 4;
            break;
        case 5:
            op = 5;
            break;
        default:
            NULL;
            break;
        }

        iCol = constr[1] - 'a' + 1;
        int *temp_res;
AG35


    #HereDoc4


    embedded_level2 = <<-eml2
        int arraySize;
        int *res;
        arraySize=get_datastructure_size(stl);

        if ( arraySize != stcsr->max_size ){
            res = (int *)sqlite3_realloc(stcsr->resultSet, sizeof(int) * arraySize);
            if (res!=NULL){
                stcsr->resultSet = res;
                memset(stcsr->resultSet, -1,
                       sizeof(int) * arraySize);
                stcsr->max_size = arraySize;
                printf("\\nReallocating resultSet..now max size %i \\n\\n", stcsr->max_size);
            }else{
                free(res);
                printf("Error (re)allocating memory\\n");
                exit(1);
            }
        }
eml2


    #HereDoc5

    auto_gen4 = <<-AG4
	temp_res = (int *)sqlite3_malloc(sizeof(int)  * stcsr->max_size);
        if ( !temp_res ){
            printf("Error in allocating memory\\n");
            exit(1);
        }

        switch( iCol ){
AG4

    fw.puts "    sqlite3_vtab_cursor *cur = (sqlite3_vtab_cursor *)stc;"
    fw.puts "    stlTable *stl = (stlTable *)cur->pVtab;"
    fw.puts "    stlTableCursor *stcsr = (stlTableCursor *)stc;"
    manage_casts(fw, ds_array)
    fw.puts "    int op, iCol, count = 0;"
    fw.puts "// val==NULL then constr==NULL also"
    fw.puts "    if ( val==NULL ){"
    if @parent.length == 0 && @signature.length > 0
      fw.puts top_level
    else
      fw.puts exit_search
    end
    fw.puts auto_gen35
    if @parent.length > 0
      if @signature.length > 0
        fw.puts embedded_level2
      end
    end
    fw.puts auto_gen4
  end


# needed?
  def process_template_name(template_name)
# C++ primitive types
    template_name.downcase!
    if template_name == "int" ||
        template_name=="float" ||
        template_name=="double"  ||
        template_name=="bool" ||
        template_name == "string"
      return 1
    else
      return 0
    end
  end

#needed?
  def process_template_names()
    if @template_args == "double"
      @template1_type += process_template_name(@template1_name)
    end
    @template2_type += process_template_name(@template2_name)
  end

# Constructs VT create queries.
  def gen_create_query()
# <db>.<table> always valid?
# <db>.<table> does not work for some reason. test.
    query =  "CREATE VIRTUAL TABLE " + @db + "." + @name  + " USING stl("
    c = 0
    while c < @columns.length
      query += @columns[c].print_col_info() + ","
      c += 1
    end
    query = query.chomp(",") + ")"
    puts query
    return query
  end

# Stores column information in a specific data structure
  def register_columns(columns)
    col = 0
    count_primitive = 0
    while col < columns.length
      @columns[col] = Column.new
      count_primitive += @columns[col].set(columns[col])
      col += 1
    end
    if count_primitive > 0
      process_template_names()
    end
  end

# Extracts column information for a VT
  def process_columns(col_string, columns)
    split_col = Array.new
    if col_string.match(/,/)
      split_col = col_string.split(/,/)
    else
      split_col[0] = col_string
    end
    columns.replace(split_col)
    l = 0
    while l < columns.length
      puts "columns[" + l.to_s + "] = " + columns[l]
      l += 1
    end
  end  

# Matches a VT description against a pattern and extracts VT traits
  def match_pattern(vt_description, columns)
    pattern = Regexp.new(/^(.+)table (\w+)\.(\w+)(\s*):(\s*)(.+)(\s*)\{(\s*)(.+)/im)
    matchdata = pattern.match(vt_description)
    if matchdata
      # First record of table_data contains the whole description of the virtual table
      # Second record contains the directives to .h files needed to link with. -> obsolete
      #      @directive = matchdata[1]
      # Third record contains the database name in which the virtual table will be created
      @db = matchdata[2]
      # Fourth record contains the virtual table name
      @name = matchdata[3]
      # Seventh record contains the signature, call to gsub to strip any whitespaces
      table_signature = matchdata[6].gsub(/\s/,"")
      verify_signature(table_signature)
      process_columns(matchdata[9], columns)
      return
    else
      pattern = /^(.+)table (\w+)\.(\w+)(\s*):(\s*)(.+)(\s*)from (\w+)(\s*)\{(\s*)(.+)/im
      matchdata = pattern.match(vt_description)
    end
    if matchdata
      # First record of table_data contains the whole description of the virtual table
      # Second record contains the directives to .h files needed to link with. -> obselete
      #      @directive = matchdata[1]
      # Third record contains the database name in which the virtual table will be created
      @db = matchdata[2]
      # Fourth record contains the virtual table name
      @name = matchdata[3]
      # Seventh record contains the signature, call to gsub to strip any whitespaces
      table_signature = matchdata[6].gsub(/\s/,"")
      # Typically, it is an embedded table, 
      # so applicable only in "FROM" cases.
      if matchdata[6].match(/^relationship_table/i)
        @signature = matchdata[6]
      else
        verify_signature(table_signature)
      end
      # Ninth record contains the parent table name
      @parent = matchdata[8]
      process_columns(matchdata[11], columns)
      return
    else
      pattern = /^table (\w+)\.(\w+)(\s*):(\s*)(.+)(\s*)from (\w+)(\s*)\{(\s*)(.+)/im
      matchdata = pattern.match(vt_description)
    end
    if matchdata
      # First record of table_data contains the whole description of the virtual table
      # Second record contains the database name in which the virtual table will be created
      @db = matchdata[1]
      # Third record contains the virtual table name
      @name = matchdata[2]
      # Sixth record contains the signature, call to gsub to strip any whitespaces
      table_signature = matchdata[5].gsub(/\s/,"")
      if matchdata[5].match(/^relationship_table/i)
        @object_class = matchdata[5]
      else
        verify_signature(table_signature)
      end
      # Eighth record contains the parent table name
      @parent = matchdata[7]
      process_columns(matchdata[10], columns)
      return
    else
      pattern = /^table (\w+)\.(\w+)(\s*):(\s*)(.+)(\s*)\{(\s*)(.+)/im
      matchdata = pattern.match(vt_description)
    end
    if matchdata
      # First record of table_data contains the whole description of the virtual table
      # Second record contains the database name in which the virtual table will be created
      @db = matchdata[1]
      # Third record contains the virtual table name
      @name = matchdata[2]
      # Sixth record contains the signature, call to gsub to strip any whitespaces
      table_signature = matchdata[5].gsub(/\s/,"")
      verify_signature(table_signature)
      process_columns(matchdata[8], columns)
    else
      puts "Invalid format. One or more of identifiers ':', 'TABLE', 'FROM''(space)' missing\n"
      exit(1)
    end
=begin
       mt = 0
       while mt < matchdata.length
         puts "matchdata[" + td.to_s + "] = " + matchdata[td]
         mt += 1
       end
=end
  end


# validate the signature of an stl structure and extract signature traits.
# Also for objects, extract class name.
  def verify_signature(table_signature)

    class_sign = <<-CS
STL class signature not properly given:
template error in #{table_signature} \n\n NOW EXITING. \n
CS

    if table_signature.include?("<") && table_signature.include?(">")
      container_split = table_signature.split(/</)
      @stl_class = container_split[0]
      if @stl_class == "list" || @stl_class == "deque"  ||
          @stl_class == "vector" || @stl_class == "slist" ||
          @stl_class == "set" || @stl_class == "multiset" ||
          @stl_class == "hash_set" || @stl_class == "hash_multiset" ||
          @stl_class == "bitset"
        @template_args = "single"
      elsif @stl_class == "map" ||
          @stl_class == "multimap" || @stl_class == "hash_map" ||
          @stl_class == "hash_multimap"
        @template_args = "double"
      else
        puts $err_state
        raise TypeError.new("no such container class: " + @stl_class +
                            "\n\n NOW EXITING. \n")
      end
      if (@template_args== "single" && container_split[1].include?(",")) ||
          (@template_args == "double" && 
           (!container_split[1].include?(",") &&
            # After splitting with '<', making sure template 
            # instantiation is not empty
            (container_split[1].chomp!(">").length != 0)))
        # double:if not normal case and not nested case raise
        raise ArgumentError.new(class_sign)
      end
      if @stl_class=="list" || @stl_class=="deque"  ||
          @stl_class=="vector" || @stl_class=="slist" ||
          @stl_class=="bitset"
        @container_type="sequence"
      elsif @stl_class=="map" ||
          @stl_class=="multimap" || @stl_class=="hash_map" ||
          @stl_class=="hash_multimap" ||
          @stl_class=="set" || @stl_class=="multiset" ||
          @stl_class=="hash_set" || @stl_class=="hash_multiset"
        @container_type="associative"
      elsif @stl_class=="bitset"
        @container_type="bitset"
      end
      puts "stl class is: " + @stl_class
      puts "no of template args is: " + @template_args
      puts "container type is: " + @container_type
      @signature = table_signature
      puts "container signature is: " + @signature
    else
      if table_signature.match(/(<*) | (>*)/)
        puts "Template instantiation identifier '<' or '>' missing\n"
        exit(1)
      end
      # Transparent inheritance

      #      if table_signature.match(/extends/i)
      #        classname_inherits = table_signature.split(/extends/i)
      #        @object_class = classname_inherits[0]
      #        @inherits = classname_inherits[1]
      #        puts "Class name : " + @object_class
      #        puts "Inherits from : " + @inherits
      #      else
      @object_class = table_signature
      puts "Class name : " + @object_class
      #      end
    end
  end


end

class Input_Description
  def initialize(description="")
    # original string description
    @description = description
    # array with entries the processed characteristics of each virtual table

    @ds_chars = Array.new
    @directives = ""
    @tokenised_dir = Array.new
    @s = "        "
  end

  def print_directives(fw, op)
    td = 0
    while td < @tokenised_dir.length
      current = @tokenised_dir[td].chomp(".h\"")
      current.gsub!(/\#include \"/,"")
      if op == 1
        fw.print current + ".o "
      elsif op == 2
        fw.print current + ".o: " + current + 
          ".cpp " + current + ".h \n" + 
          "\tg++ -W -g -c " + current + ".cpp \n\n"
      end
      td += 1
    end
  end

  def tokenise_directive()
    # to distinguish between directives for helper classes and directives for user defined classes (empty line between the two)
    if @directives.match(/\n\n/)
      directives = @directives.split(/\n\n/)
      if directives[1].match(/\n/)
        @tokenised_dir = directives[1].split(/\n/)
      else
        @tokenised_dir[0] = directives[1]
      end
    end
  end

# Generates the application-specific retrieve method for each VT struct.
  def print_retrieve_functions(fw)
    w = 0
    while w < @ds_chars.length
      curr_ds = @ds_chars[w]
      fw.puts "int " + curr_ds.name +
        "_retrieve(void *stc, int n, sqlite3_context *con){"
      curr_ds.setup_retrieve(fw, @ds_chars)
      curr_ds.retrieve_columns(fw)
      fw.puts "    }"
      fw.puts "    return SQLITE_OK;"
      fw.puts "}\n\n\n"
      w += 1
    end
    fw.puts "int retrieve(void* stc, int n, sqlite3_context *con){"
    fw.puts "    sqlite3_vtab_cursor *cur = (sqlite3_vtab_cursor *)stc;"
    fw.puts "    stlTable *stl = (stlTable *)cur->pVtab;"
    w = 0
    while w < @ds_chars.length
      curr_ds = @ds_chars[w]
      fw.puts "    if( !strcmp(stl->zName, \"" + curr_ds.name + "\") )"
      fw.puts "        return " + curr_ds.name +
        "_retrieve(stc, n, con);"
      w += 1
    end
    fw.puts "}\n\n"
  end

# Generates the application-specific search method for each VT struct.
  def print_search_functions(fw)

    #HereDoc1

       cls_search = <<-cls
// more datatypes and ops exist
        }
        int ia, ib;
        int *i_res;
        int i_count = 0;
        if (stcsr->size == 0){
            memcpy(stcsr->resultSet, temp_res, sizeof(int) *
                                     stcsr->max_size);
            stcsr->size = count;
        }else{
            i_res = (int *)sqlite3_malloc(sizeof(int) *
                                        stcsr->max_size);
            for(int a=0; a<stcsr->size; a++){
                for(int b=0; b<count; b++){
                    ia = stcsr->resultSet[a];
                    ib = temp_res[b];
                    if( ia==ib ){
                        i_res[i_count++] = ia;
                        b++;
                    }else if( ia < ib )
                        b = count;
                    else
                        b++;
		}
            }
            assert( i_count <= stcsr->max_size );
            memcpy(stcsr->resultSet, i_res, sizeof(int) *
                                     i_count);
            stcsr->size = i_count;
            sqlite3_free(i_res);
        }
        sqlite3_free(temp_res);
    }
}


cls

    w = 0
    while w < @ds_chars.length
      curr_ds = @ds_chars[w]
      fw.puts "void " + curr_ds.name +
        "_search(void *stc, char *constr, sqlite3_value *val){"
      curr_ds.setup_search(fw, @ds_chars)
      curr_ds.search_columns(fw)
# Needs update I think.
      fw.puts cls_search
      w += 1
    end
    fw.puts "void search(void* stc, char *constr, sqlite3_value *val){"
    fw.puts "    sqlite3_vtab_cursor *cur = (sqlite3_vtab_cursor *)stc;"
    fw.puts "    stlTable *stl = (stlTable *)cur->pVtab;"
    w = 0
    while w < @ds_chars.length
      curr_ds = @ds_chars[w]
      fw.puts "    if( !strcmp(stl->zName, \"" + curr_ds.name + "\") )"
      fw.puts "        " + curr_ds.name +
        "_search(stc, constr, val);"
      w += 1
    end
    fw.puts "}\n\n"
  end

# Generates method that returns size of each VT struct.
  def print_ds_size_functions(fw)
    fw.puts "int get_datastructure_size(void *st){"
    fw.puts "    stlTable *stl = (stlTable *)st;"
    w = 0
    while w < @ds_chars.length
      curr_ds = @ds_chars[w]
# if not a shared object print:
      if curr_ds.signature.length > 0
        fw.puts "    if( !strcmp(stl->zName, \"" + curr_ds.name + "\") )\
{"
        fw.puts "        " + curr_ds.signature + " *any_dstr = (" +
          curr_ds.signature + " *)stl->data;"
        fw.puts "        return ((int)any_dstr->size());"
        fw.puts "    }"
      end
      w += 1
    end
    fw.puts "}"
  end


# Generates application-specific code to complement the SQTL library.
  def generate()

   #HereDoc1

      auto_gen1 = <<-AG1

using namespace std;



void * thread_sqlite(void *data){
  const char **queries;
  queries = (const char **)sqlite3_malloc(sizeof(char *) *
                   #{@ds_chars.length.to_s});
  int failure = 0;
AG1

   #HereDoc2

      auto_gen2 = <<-AG2
  failure = register_table( "#{@ds_chars[0].db}" ,  #{@ds_chars.length.to_s}, queries,
           data, enter 1 if table is to be created 0 if already created);
  printf(\"Thread sqlite returning..\\n\");
  sqlite3_free(queries);
  return (void *)failure;
}


/* comparison function for datastructure if needed
struct classcomp{
    bool operator() (const USER_CLASS& uc1, const USER_CLASS& uc2) const{
        return (uc1.get_known_type()<uc2.get_known_type());
    }
};
// in main: include classcomp in template arguments
*/


int main(){
// allocations and initialisations
  int re_sqlite;
  void *data;
  char *helper;

  //names of data structures to be registered
  const char *name1 = "to be filled_in";
  int n_name1 = (int)strlen(name1) + 1;
  // etc for subsequent data structures. eg:
  // const char *name2 = "to be filled_in";
  // int n_name2 = (int)strlen(name2) + 1;
  // length of data structures names

  dsCarrier *dsC;
  int nByte = sizeof(dsCarrier) + sizeof(long int *) * 2 +
    sizeof(const char *) * 2 + n_name1;
  // etc for subsequent data structures. eg: + n_name2;
  dsC = (dsCarrier *)sqlite3_malloc(nByte);
  memset(dsC, 0, nByte);
  pthread_t sqlite_thread;

// assignment of data structure characteristics to dsC
  // number of data structures to register
  dsC->size = to be filled_in;
  dsC->dsNames = (const char **)&dsC[1];
  dsC->memories = (long int **)&dsC->dsNames[dsC->size];
  helper = (char *)&dsC->memories[dsC->size];

  dsC->memories[0] = (long int *) to be filled in with memory address;
  // etc for subsequent data structures. eg:
  // dsC->memories[1] = (long int *) to be filled in with memory address;


  dsC->dsNames[0] = helper;
  memcpy(helper, name1, n_name1);
  helper += n_name1;
  // etc for subsequent data structures
  // dsC->dsNames[1] = helper;
  memcpy(helper, name1, n_name1);
  helper += n_name1;
  // etc for subsequent data structures
  // dsC->dsNames[1] = helper;
  // memcpy(helper, name2, n_name2);
  // helper += n_name2;

  assert(helper <= &((char *)dsC)[nByte]);

  data = (void *)dsC;

  re_sqlite = pthread_create(&sqlite_thread, NULL, thread_sqlite, data);
  pthread_join(sqlite_thread, NULL);
  printf(\"Thread sqlite returned %i\\n\", re_sqlite);
}


AG2


    #HereDoc3


        auto_gen3 = <<-AG3


int traverse(int dstr_value, int op, int value){
    switch( op ){
    case 0:
        return dstr_value<value;
    case 1:
        return dstr_value<=value;
    case 2:
        return dstr_value==value;
    case 3:
        return dstr_value>=value;
    case 4:
        return dstr_value>value;
    }
}


int traverse(double dstr_value, int op, double value){
    switch( op ){
    case 0:
        return dstr_value<value;
    case 1:
        return dstr_value<=value;
    case 2:
        return dstr_value==value;
    case 3:
        return dstr_value>=value;
    case 4:
        return dstr_value>value;
    }
}

// compare addresses???
int traverse(const void *dstr_value, int op, const void *value){
    switch( op ){
    case 0:
        return dstr_value<value;
    case 1:
        return dstr_value<=value;
    case 2:
        return dstr_value==value;
    case 3:
        return dstr_value>=value;
    case 4:
        return dstr_value>value;
    }
}


int traverse(const unsigned char *dstr_value, int op,
                   const unsigned char *value){
    switch( op ){
    case 0:
        return strcmp((const char *)dstr_value,(const char *)value)<0;
    case 1:
        return strcmp((const char *)dstr_value,(const char *)value)<=0;
    case 2:
        return strcmp((const char *)dstr_value,(const char *)value)==0;
    case 3:
        return strcmp((const char *)dstr_value,(const char *)value)>=0;
    case 4:
        return strcmp((const char *)dstr_value,(const char *)value)>0;
    }
}




AG3


    #HereDoc4


  makefile_part = <<-mkf

main.o: main.cpp Account.h bridge.h
        g++ -W -g -c main.cpp

user_functions.o: user_functions.c bridge.h
        gcc -W -g -c user_functions.c

stl_to_sql.o: stl_to_sql.c stl_to_sql.h bridge.h
        gcc -g -c stl_to_sql.c

search.o: search.cpp bridge.h Account.h
        g++ -W -g -c search.cpp
mkf

    myfile = File.open("main_v2.template", "w") do |fw|
      fw.puts "\#include <stdio.h>"
      fw.puts "\#include <string>"
      fw.puts "\#include \"stl_to_sql.h\""
      fw.puts "\#include <pthread.h>"
      fw.puts @directives
      fw.puts auto_gen1
      w = 0
      while w < @ds_chars.length
        curr_ds = @ds_chars[w]
        # probably needs processing
        fw.puts "  queries[" + w.to_s + "] = \"" + curr_ds.gen_create_query() + "\";"
        w += 1
      end
      fw.puts auto_gen2
    end
    myfile = File.open("search_v2.cpp", "w") do |fw|
      fw.puts "\#include \"search.h\""
      fw.puts "\#include <string>"
      fw.puts @directives
      #can be made faster. call once, store in string and fw.puts string
      fw.puts
      fw.puts "using namespace std;\n\n"      
# print_set_dependencies
# print_realloc_carrier
# print_update_structures
      print_ds_size_functions(fw)
# print_realloc_resultset
      fw.puts auto_gen3
      print_search_functions(fw)
      print_retrieve_functions(fw)
    end
    myFile = File.open("makefile_v2", "w") do |fw|
      fw.print "test: main.o search.o stl_to_sql.o user_functions.o "
      tokenise_directive()
      print_directives(fw, 1)
      fw.print "\n    g++ -lswill -lsqlite3 -W -g main.o search.o stl_to_sql.o user_functions.o "
      print_directives(fw, 1)
      fw.puts "-o test"
      fw.puts makefile_part
      fw.puts
      print_directives(fw, 2)
    end
  end

# User description first comes here. Description is cleaned from 
# surplus spaces and is split to extract directives to external 
# application and library files. 
# Each VT description is separated, matched against specific patterns
# and all elements are recorded including column specifications.
  def register_datastructure
    puts "description before whitespace squeeze " + @description
    @description.squeeze!(' ')
    puts "description after whitespace squeeze " + @description
    if @description.match(/table/i)
      prep_dir = @description.split(/table/i)
      @directives = prep_dir[0]
      puts "Directives: " + @directives
    else
      puts "Invalid description"
      exit(1)
    end
    if @description.match(/\}/)
      ds = @description.split(/\}/)
    else
      puts "Invalid format terminal identifier '}' missing"
    end
    columns = Array.new
    w = 0
    while w < ds.length
      puts "\nDATA STRUCTURE DESCRIPTION No: " + w.to_s + "\n"
      @ds_chars[w] = Data_structure_characteristics.new
      # in case each VT description is in a separate line
      if ds[w].match(/\n/)
        ds[w].gsub!(/\n/,"")
      end
      @ds_chars[w].match_pattern(ds[w], columns)
      @ds_chars[w].register_columns(columns)
      w += 1
    end
    generate()
  end
end



if __FILE__==$0
  description = "#include <stdio.h>
#include <assert.h>
#include <string>
#include <vector>

#include \"Truck.h\"
#include \"Customer.h\"
TABLE foo.Trucks : vector<Truck*> {truck_id INT FROM &Truck}
TABLE foo.Truck : Truck FROM Trucks {truck_id INT FROM &, cost DOUBLE FROM get_cost(), delcapacity INT FROM get_delcapacity(), pickcapacity INT FROM get_pickcapacity(), rlpoint INT FROM get_rlpoint()}
TABLE foo.Truck_Customers : RELATIONSHIP_TABLE FROM Truck {truck_id INT FROM &Truck, customers_id INT FROM &Customers get_customers()}
TABLE foo.Customers : vector<Customer *> FROM Truck_Customers {customers_id INT FROM &, customer_id INT FROM &Customer}
TABLE foo.Customer : Customer FROM Customers {customer_id INT FROM &, demand INT FROM get_demand(), code STRING from get_code(), serviced INT from get_serviced(), pickdemand INT FROM get_pickdemand(), starttime INT FROM get_starttime(), servicetime INT FROM get_servicetime(), finishtime INT FROM get_finishtime(), revenue INT FROM get_revenue()}"
  input = Input_Description.new(description)
  input.register_datastructure
end
