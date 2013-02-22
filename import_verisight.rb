require '/Users/pz/0_Moneydance_Scripts/md_str_utils.rb'
require '/Users/pz/0_Moneydance_Scripts/md_acct_utils.rb'

def process_verisight_row(row, inv_acct, xfr_acct, bank_acct)
  rownum = row['row_num']
  date = row['Trade Date']
  desc = row['Transaction']
  if date.length == 0 || desc.length == 0
    puts "line #{rownum} ignored: no date or activity"
    return 0
  end
  amt = row['Transaction Amount']
  val = row['Shares This Transaction']
  if amt.length == 0 && val.length == 0
    puts "line #{rownum} ignored: no amt and no val"
    return 0
  end
  sec_acct = nil
  ticker_sym = row['Ticker']
  if ticker_sym.length > 0
    sec_acct = get_security_acct(inv_acct, ticker_sym)
    if !sec_acct
      puts "line #{rownum} ignored: no #{ticker_sym} security in acct"
      return 0
    end
  end
  amt = md_qty_to_int(amt, 2) # in MS file, buy is < 0, sell is > 0
  if !sec_acct
    sec_acct = bank_acct # bank_acct is because MS doesn't put ticker on interest payments
    val = 0
  else
    decimals = sec_acct.getCurrencyType().getDecimalPlaces()
    val = md_qty_to_int(val, decimals) # in MS file, always > 0
  end
  memo = ''
  price = row['Share Price'] # not used
  action = ''
  detail = row['Investments']
  if desc == 'Contribution'
    action = 'BuyXfr'
    memo = desc
  elsif desc == 'Exchange Purchase'
    action = 'Buy'
    memo = desc
  elsif desc == 'Exchange Redemption'
    action = 'Sell'
    memo = desc
  elsif desc == 'Dividend Reinvestment'
    action = 'DivReinvest'
    memo = desc
  elsif desc == 'Increase Earnings'
    puts "line #{rownum} ignored: no transaction for '#{desc}'"
    return 0
  else
    puts "line #{rownum} ignored: don't understand activity '#{desc}'"
    return 0
  end
  rate = amt != 0 ? val.to_f/amt.to_f : 1.0
  date_int = md_date_to_int(date)
  puts "line #{rownum}: date #{date_int} action #{action} ticker '#{ticker_sym}' activity '#{desc}'"
  add_new_txn_in_acct(inv_acct, sec_acct, xfr_acct, date_int, desc, memo, action, amt, val, rate)
  return 1
end

puts "starting script"
import_file   = '/Users/pz/Documents/VSGHT.csv'
inv_acct_name = 'Verisight 401K'

inv_acct, xfr_acct, bank_acct = get_txn_accounts(inv_acct_name, 'Unassigned', 'MSBNK')
if !inv_acct
  puts "cannot verify - missing inv_acct"
else
  rv = 0
  verify_tickers(import_file, inv_acct, 'Ticker') do |tickers|
    if tickers.empty?
      rv = 1
    else
      puts tickers.inspect
    end
  end
  if rv == 0
    puts "fix missing ticker symbols and run again"
  elsif !xfr_acct
    puts "cannot import - missing xfr_acct"
  else
    rows = 0
    process_csv_file(import_file) do |row|
      rv = process_verisight_row(row, inv_acct, xfr_acct, bank_acct)
      rows += 1
    end
    puts "processed #{rows} rows"
  end
end
