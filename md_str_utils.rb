def split_quoted_line(line)
  fnum = 0
  fields = [ ]
  in_quote = 0
  skip_to_comma = 0
  line = line.strip
  l = line.length
  i = 0
  fstart = 0
  fend = 0
  while i < l
    c = line[i, 1]
    i += 1
    if c == ','
      if in_quote != 0
        fend = fend + 1
      else
        skip_to_comma = 0
        f = line[fstart, fend-fstart].strip
        fields << f
        fstart = i
        fend = i
      end
    elsif c == '"'
      if in_quote != 0
        in_quote = 0
        skip_to_comma = 1
        next
      else
        in_quote = 1
        skip_to_comma = 0
        fstart = i
        fend = i
      end
    elsif skip_to_comma == 0
      fend = fend + 1
    end
  end
  f = line[fstart, fend-fstart].strip
  fields << f
  fields
end

def md_date_to_int(date_str)
  dates = date_str.split('/')
  mm = dates[0]
  dd = dates[1]
  yyyy = dates[2]
  mm = '0' + mm if mm.length == 1
  dd = '0' + dd if dd.length == 1
  yyyy = '20' + yyyy if yyyy.length == 2 
  int_val = (yyyy + mm + dd).to_i
  int_val
end

def md_qty_to_int(qty_str, decimals)
  l = qty_str.length
  if l == 0
    return 0
  end
  neg = ''
  md = ''
  frac = ''
  i = 0
  while i < l
    c = qty_str[i, 1]
    i += 1
    next if c == '$' or c == ',' or c == ')'
    if c == '('
      neg = '-'
    elsif c == '.'
      frac = qty_str[i, decimals]
      i = l
    else
      md << c
    end
  end
  while frac.length < decimals
    frac << '0'
  end
  int_val = (neg + md + frac).to_i
  int_val
end

