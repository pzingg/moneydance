from com.moneydance.apps.md.model import AbstractTxn, ParentTxn, SplitTxn

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

def mdDate(dateStr):
  dates = dateStr.split('/')
  mm = dates[0]
  if len(mm) < 2:
    mm = '0' + mm
  dd = dates[1]
  if len(dd) < 2:
    dd = '0' + dd
  return int(dates[2] + mm + dd)

def mdQty(qtyStr, decimals):
  l = len(qtyStr)
  if l == 0:
    return 0
  neg = ''
  md = ''
  frac = ''
  i = 0
  while i < l:
    c = qtyStr[i]
    i = i + 1
    if c == '(':
      neg = '-'
    elif c == '$' or c == ',' or c == ')':
      pass
    elif c == '.':
      frac = qtyStr[i:i+decimals]
      i = l
    else:
      md = md + c
  while len(frac) < decimals:
    frac = frac + '0'
  return int(neg + md + frac)

def processTxn(rootAcct, invAcct, secAcct, autoAcct, dateInt, desc, memo, action, amt, val, rate):
  txnSet = rootAcct.getTransactionSet()  
  txn = ParentTxn(dateInt, dateInt, dateInt, "", invAcct,  desc, memo, -1, AbstractTxn.STATUS_UNRECONCILED)
  if action == 'Buy' or action == 'Sell':
    txn.setTransferType(AbstractTxn.TRANSFER_TYPE_BUYSELL)
    secSplit = SplitTxn(txn, amt, val, rate, secAcct, desc, -1, AbstractTxn.STATUS_UNRECONCILED)
    secSplit.setTag('invest.splittype', 'sec')
    txn.addSplit(secSplit)
  elif action == 'BuyXfr' or action == 'SellXfr':
    txn.setTransferType(AbstractTxn.TRANSFER_TYPE_BUYSELLXFR)
    secSplit = SplitTxn(txn, amt, val, rate, secAcct, desc, -1, AbstractTxn.STATUS_UNRECONCILED)
    secSplit.setTag('invest.splittype', 'sec')
    txn.addSplit(secSplit)
    incSplit = SplitTxn(txn, -amt, -amt, 1.0, autoAcct, '', -1, AbstractTxn.STATUS_UNRECONCILED)
    incSplit.setTag('invest.splittype', 'xfr')
    txn.addSplit(incSplit)
  elif action == 'Dividend':
    txn.setTransferType(AbstractTxn.TRANSFER_TYPE_DIVIDEND)
    txn.setTag('reinvest', 'false')
    secSplit = SplitTxn(txn, 0, 0, 1.0, secAcct, desc, -1, AbstractTxn.STATUS_UNRECONCILED)
    secSplit.setTag('invest.splittype', 'sec')
    txn.addSplit(secSplit)
    incSplit = SplitTxn(txn, -amt, -amt, 1.0, autoAcct, '', -1, AbstractTxn.STATUS_UNRECONCILED)
    incSplit.setTag('invest.splittype', 'inc')
    txn.addSplit(incSplit)
  elif action == 'DivReinvest':
    txn.setTransferType(AbstractTxn.TRANSFER_TYPE_DIVIDEND)
    txn.setTag('reinvest', 'true')
    secSplit = SplitTxn(txn, amt, val, rate, secAcct, desc, -1, AbstractTxn.STATUS_UNRECONCILED)
    secSplit.setTag('invest.splittype', 'sec')
    txn.addSplit(secSplit)
    incSplit = SplitTxn(txn, -amt, -amt, 1.0, autoAcct, '', -1, AbstractTxn.STATUS_UNRECONCILED)
    incSplit.setTag('invest.splittype', 'inc')
    txn.addSplit(incSplit)
  elif action == 'MiscInc' or action == 'MiscExp':
    txn.setTransferType(AbstractTxn.TRANSFER_TYPE_MISCINCEXP)
    secSplit = SplitTxn(txn, 0, 0, rate, secAcct, desc, -1, AbstractTxn.STATUS_UNRECONCILED)
    secSplit.setTag('invest.splittype', 'sec')
    txn.addSplit(secSplit)
    incSplit = SplitTxn(txn, -amt, -amt, 1.0, autoAcct, '', -1, AbstractTxn.STATUS_UNRECONCILED)
    if action == 'MiscInc':
      incSplit.setTag('invest.splittype', 'inc')
    else:
      incSplit.setTag('invest.splittype', 'exp')
    txn.addSplit(incSplit)
  txnSet.addNewTxn(txn)

def getSecurityAcct(rootAcct, invAcct, tickerSym):
  currencies = rootAcct.getCurrencyTable()
  curr = currencies.getCurrencyByTickerSymbol(tickerSym)
  if curr is None:
    print tickerSym, " security not found"
    return None
  secAcctName = invAcct.getAccountName() + ':' + curr.getName()
  secAcct = rootAcct.getAccountByName(secAcctName)
  if secAcct is None:
    print secAcctName, " security acct not found"
  return secAcct

def processRow(row, rootAcct, invAcct, autoAcct, bankAcct):
  amt = row['Amount']
  val = row['Quantity']
  if len(amt) == 0 and len(val) == 0:
    return 0
  secAcct = bankAcct
  tickerSym = row['Symbol']
  if len(tickerSym) > 0:
    secAcct = getSecurityAcct(rootAcct, invAcct, tickerSym)
    if secAcct is None:
      return 0
  decimals = secAcct.getCurrencyType().getDecimalPlaces()
  dateInt = mdDate(row['Date'])
  amt = mdQty(amt, 2) # in AT file, buy is > 0, sell is < 0
  val = mdQty(val, decimals)  # in AT file, buy is > 0, sell is < 0
  desc = row['Category']
  memo = ''
  price = row['Price'] # not used
  action = row['Action']
  detail = row['Transaction Type']
  add_action = None
  if action == 'Buy':
    if detail.find('Gain/Loss') >= 0:
      add_action = 'MiscInc'
      memo = 'Gain'
    elif detail.find('contribution') >= 0: # or dateInt == 20070910 (initial)
      action = 'BuyXfr'
    else:
      pass
  elif action == 'Sell':
    if detail.find('Gain/Loss') >= 0:
      add_action = 'MiscExp'
      memo = 'Loss'
  elif action == 'REINVDIV':
    action = 'DivReinvest'
  else:
    print "unhandled action ", action
    return 0
  rate = 1.0
  if amt <> 0:
    rate = float(val)/float(amt)
  print "ticker ", tickerSym, " date ", dateInt, " action ", action
  processTxn(rootAcct, invAcct, secAcct, autoAcct, dateInt, desc, memo, action, amt, val, rate)
  if add_action is not None:
    processTxn(rootAcct, invAcct, secAcct, autoAcct, dateInt, desc, memo, add_action, amt, val, rate)
  rootAcct.refreshAccountBalances()
  return 1

def processCsv(md, csvFileName, accountName, bankTicker):
  rootAcct = md.getRootAccount()
  invAcct = rootAcct.getAccountByName(accountName)
  autoAcct = rootAcct.getAccountByName('Auto')
  if invAcct is None or autoAcct is None:
    return
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
      rv = processRow(row, rootAcct, invAcct, autoAcct, None)
    s = reader.readline()

processCsv(moneydance, '/Users/pz/Desktop/Moneydance/python/AccountTrax.csv', 'Test', None)
