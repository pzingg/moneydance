from com.moneydance.apps.md.model import Account, SecurityAccount, SecurityType

def splitQuotedLine(line):
  fnum = 0
  fields = [ ]
  in_quote = 0
  skip_to_comma = 0
  l = len(line)
  i = 0
  fstart = 0
  fend = 0
  while i < l:
    c = line[i]
    i = i + 1
    if c == ',':
      if in_quote <> 0:
        fend = fend + 1
      else:
        skip_to_comma = 0
        f = line[fstart:fend].strip()
        fields.append(f)
        fstart = i
        fend = i
    elif c == '"':
      if in_quote <> 0:
        in_quote = 0
        skip_to_comma = 1
        continue
      else:
        in_quote = 1
        skip_to_comma = 0
        fstart = i
        fend = i
    elif skip_to_comma == 0:
      fend = fend + 1
  f = line[fstart:fend].strip()
  fields.append(f)
  return fields

def dumpSecurityAccountMeta(acct, f):
  curr = acct.getCurrencyType()
  fullName = acct.getFullAccountName()
  currName = curr.getName()
  ticker = curr.getTickerSymbol()
  secType = acct.getSecurityType()
  secType = str(secType)
  subType = ''
  bondType = ''
  apr = ''
  maturity = ''
  optType = ''
  optPrice = ''
  strikePrice = ''
  if secType == 'BOND':
    bondType = ('Government','Municipal','Corporate','Zero-Coupon')[acct.getBondType()]
    apr = acct.getAPR()
    maturity = acct.getMaturity()
  elif secType == 'CD':
    apr = acct.getAPR()
    maturity = acct.getMaturity()
  elif secType == 'MUTUAL' or secType == 'STOCK':
    subType = acct.getParameter('sec_subtype')
  elif secType == 'OPTION':
    if acct.getPut():
      optType = 'Put'
    else:
      optType = 'Get'
    optPrice = acct.getOptionPrice()
    strikePrice = acct.getStrikePrice()
  else:
    pass
  line = "\t".join((fullName, currName, ticker, secType, subType, bondType, apr, maturity, optType, optPrice, strikePrice)) + "\n"
  f.write(line)

def dumpAllSecurityAccountMeta(md, fileName):
  f = open(fileName, 'wb')
  line = "\t".join(('fullName', 'currName', 'ticker', 'secType', 'subType', 'bondType', 'apr', 'maturity', 'optType', 'optPrice', 'strikePrice')) + "\n"
  f.write(line)
  
  rootAcct = md.getRootAccount()
  for acct in rootAcct.getSubAccounts():
    if acct.getAccountType() != Account.ACCOUNT_TYPE_INVESTMENT:
      continue
    print "inv acct name ", acct.getAccountName()
    for secAcct in acct.getSubAccounts():
      subType = secAcct.getAccountType()
      if subType == Account.ACCOUNT_TYPE_SECURITY:
        dumpSecurityAccountMeta(secAcct, f)
  f.close()

def processRow(row, rootAcct):
  acctName = row['fullName']
  acct = rootAcct.getAccountByName(acctName)
  if acct is None:
    print "could not find ", acctName
    return 0
  acctType = acct.getAccountType()
  if acctType <> Account.ACCOUNT_TYPE_SECURITY:
    print "acct skipped ", acct.getFullAccountName()
    return 0
  print row['fullName']
  secType = row['secType']
  subType = row['subType']
  if secType == 'BOND':
    apr = float(row['apr'])
    acct.setSecurityType(SecurityType.BOND)
    acct.setBondType(1)
    acct.setAPR(apr)
    print "set type ", secType
  elif secType == 'MUTUAL':
    acct.setSecurityType(SecurityType.MUTUAL)
    acct.setParameter('sec_subtype', subType)
    print "set type ", secType, " ", subType
  elif secType == 'STOCK':
    acct.setSecurityType(SecurityType.STOCK)
    acct.setParameter('sec_subtype', subType)
    print "set type ", secType, " ", subType
  else:
    print "skipped type ", secType
    return 0
  acct.setPrefix(None) # clear these
  acct.setSuffix(None)
  return 1

def processCsv(md, csvFileName):
  rootAcct = md.getRootAccount()
  reader = open(csvFileName, 'rb')
  headers = None
  rownum = 0
  s = reader.readline()
  while len(s) > 0:
    fields = splitQuotedLine(s)
    if headers is None:
      headers = fields
      nfields = len(headers)
    else:
      row = { }
      rownum = rownum + 1
      i = 0
      while i < nfields:
        row[headers[i]] = fields[i]
        i = i + 1
      rv = processRow(row, rootAcct)
    s = reader.readline()

processCsv(moneydance, '/Users/pz/security_info.csv')
