import com.moneydance.apps.md.model.AbstractTxn
import com.moneydance.apps.md.model.ParentTxn
import com.moneydance.apps.md.model.SplitTxn

def get_security_acct(inv_acct, ticker_sym)
  currencies = ROOT.getCurrencyTable()
  curr = currencies.getCurrencyByTickerSymbol(ticker_sym)
  if !curr
    puts "#{ticker_sym} security not found"
    return nil
  end
  sec_acct_name = "#{inv_acct.getAccountName()}:#{curr.getName()}"
  sec_acct = ROOT.getAccountByName(sec_acct_name)
  if !sec_acct
    puts "#{sec_acct_name} security acct not found"
  end
  sec_acct
end

def get_txn_accounts(inv_acct_name, xfr_category_name, bank_ticker_sym)
  inv_acct = ROOT.getAccountByName(inv_acct_name)
  if !inv_acct
    puts "could not find account #{inv_acct_name}"
    return [nil, nil, nil]
  end
  xfr_acct = nil
  if xfr_category_name
    xfr_acct = ROOT.getAccountByName(xfr_category_name)
    if !xfr_acct
      puts "count not find category #{xfr_category_name}"
    end
  end
  if !xfr_acct
    xfr_acct = inv_acct.getDefaultCategory()
    if !xfr_acct
      puts "could not get default category for account"
    end
  end
  bank_acct = get_security_acct(inv_acct, bank_ticker_sym)
  if !bank_acct
    puts "could not find money market security #{bank_ticker_sym}"
  end
  [inv_acct, xfr_acct, bank_acct]
end

def add_new_txn_in_acct(inv_acct, sec_acct, xfr_acct, date_int, desc, memo, action, amt, val, rate)
  if !sec_acct && (action == 'Buy' || action == 'Sell' || 
      action == 'BuyXfr' || action == 'SellXfr' ||
      action == 'Dividend' || action == 'DivReinvest' ||
      action == 'MiscInc' || action == 'MiscExp')
    puts "Security-related transaction cannot be processed: no security acct"
    return 0
  end
  txn = ParentTxn.new(date_int, date_int, date_int, "", inv_acct,  desc, memo, -1, AbstractTxn::STATUS_UNRECONCILED)
  if action == 'Buy' || action == 'Sell'
    txn.setTransferType(AbstractTxn::TRANSFER_TYPE_BUYSELL)
    secSplit = SplitTxn.new(txn, amt, val, rate, sec_acct, desc, -1, AbstractTxn::STATUS_UNRECONCILED)
    secSplit.setTag('invest.splittype', 'sec')
    txn.addSplit(secSplit)
  elsif action == 'BuyXfr' || action == 'SellXfr'
    txn.setTransferType(AbstractTxn::TRANSFER_TYPE_BUYSELLXFR)
    secSplit = SplitTxn.new(txn, amt, val, rate, sec_acct, desc, -1, AbstractTxn::STATUS_UNRECONCILED)
    secSplit.setTag('invest.splittype', 'sec')
    txn.addSplit(secSplit)
    incSplit = SplitTxn.new(txn, -amt, -amt, 1.0, xfr_acct, '', -1, AbstractTxn::STATUS_UNRECONCILED)
    incSplit.setTag('invest.splittype', 'xfr')
    txn.addSplit(incSplit)
  elsif action == 'Xfr'
    txn.setTransferType(AbstractTxn::TRANSFER_TYPE_BANK)
    incSplit = SplitTxn.new(txn, -amt, -amt, 1.0, xfr_acct, '', -1, AbstractTxn::STATUS_UNRECONCILED)
    incSplit.setTag('invest.splittype', 'xfr')
    txn.addSplit(incSplit)
  elsif action == 'Dividend'
    txn.setTransferType(AbstractTxn::TRANSFER_TYPE_DIVIDEND)
    txn.setTag('reinvest', 'false')
    secSplit = SplitTxn.new(txn, 0, 0, 1.0, sec_acct, desc, -1, AbstractTxn::STATUS_UNRECONCILED)
    secSplit.setTag('invest.splittype', 'sec')
    txn.addSplit(secSplit)
    incSplit = SplitTxn.new(txn, -amt, -amt, 1.0, xfr_acct, '', -1, AbstractTxn::STATUS_UNRECONCILED)
    incSplit.setTag('invest.splittype', 'inc')
    txn.addSplit(incSplit)
  elsif action == 'DivReinvest'
    txn.setTransferType(AbstractTxn::TRANSFER_TYPE_DIVIDEND)
    txn.setTag('reinvest', 'true')
    secSplit = SplitTxn.new(txn, amt, val, rate, sec_acct, desc, -1, AbstractTxn::STATUS_UNRECONCILED)
    secSplit.setTag('invest.splittype', 'sec')
    txn.addSplit(secSplit)
    incSplit = SplitTxn.new(txn, -amt, -amt, 1.0, xfr_acct, '', -1, AbstractTxn::STATUS_UNRECONCILED)
    incSplit.setTag('invest.splittype', 'inc')
    txn.addSplit(incSplit)
  elsif action == 'MiscInc' || action == 'MiscExp'
    txn.setTransferType(AbstractTxn::TRANSFER_TYPE_MISCINCEXP)
    secSplit = SplitTxn.new(txn, 0, 0, 1.0, sec_acct, desc, -1, AbstractTxn::STATUS_UNRECONCILED)
    secSplit.setTag('invest.splittype', 'sec')
    txn.addSplit(secSplit)
    incSplit = SplitTxn.new(txn, -amt, -amt, 1.0, xfr_acct, '', -1, AbstractTxn::STATUS_UNRECONCILED)
    if action == 'MiscInc'
      incSplit.setTag('invest.splittype', 'inc')
    else
      incSplit.setTag('invest.splittype', 'exp')
    end
    txn.addSplit(incSplit)
  end
  TRANS.addNewTxn(txn)
  ROOT.refreshAccountBalances()
  puts "transaction added"
  return 1
end

def verify_tickers(csv_file_name, inv_acct, ticker_hdr)
  missing_tickers = { }
  headers = nil
  nfields = 0
  rownum = 0
  reader = open(csv_file_name, 'rb')
  while (s = reader.gets)
    line = s.strip
    fields = split_quoted_line(line)
    if !headers
      headers = fields
      nfields = headers.size
    else
      rownum += 1
      row = { 'row_num' => rownum }
      i = 0
      while i < nfields
        row[headers[i]] = fields[i]
        i += 1
      end
      ticker_sym = row[ticker_hdr]
      if ticker_sym.length > 0 && !missing_tickers.key?(ticker_sym)
        if !get_security_acct(inv_acct, ticker_sym)
          missing_tickers[ticker_sym] = row['Description']
        end
      end
    end
  end
  yield missing_tickers
  rv = missing_tickers.size > 0 ? 0 : rownum
  rv
end

def process_csv_file(csv_file_name)
  headers = nil
  nfields = 0
  rownum = 0
  reader = open(csv_file_name, 'rb')
  while (s = reader.gets)
    line = s.strip
    fields = split_quoted_line(line)
    if !headers
      headers = fields
      nfields = headers.size
    else
      rownum += 1
      row = { 'row_num' => rownum }
      i = 0
      while i < nfields
        row[headers[i]] = fields[i]
        i += 1
      end
      yield row
    end
  end
  rv = rownum
end

