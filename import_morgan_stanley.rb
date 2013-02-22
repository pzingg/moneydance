require '/Users/pz/0_Moneydance_Scripts/md_str_utils.rb'
require '/Users/pz/0_Moneydance_Scripts/md_acct_utils.rb'

def process_morgan_stanley_row(row, inv_acct, xfr_acct, bank_acct)
  rownum = row['row_num']
  date = row['Date']
  desc = row['Activity']
  if date.length == 0 || desc.length == 0
    puts "line #{rownum} ignored: no date or activity"
    return 0
  end
  amt = row['Amount']
  val = row['Quantity']
  if amt.length == 0 && val.length == 0
    puts "line #{rownum} ignored: no amt and no val"
    return 0
  end
  sec_acct = nil
  ticker_sym = row['Symbol']
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
  price = row['Price'] # not used
  action = ''
  detail = row['Description']
  if desc == 'Bought'
    action = 'Buy'
    desc = ''
    amt = -amt # now amt is > 0
  elsif desc == 'Automatic Reinvestment' || desc == 'Automatic Investment'
    action = 'Buy'
    memo = detail
    amt = -amt # now amt is > 0
  elsif desc == 'Sold'
    action = 'Sell'
    desc = ''
    amt = -amt # now amt is < 0
    val = -val # now val is < 0
  elsif desc == 'Sold (Rebook)'
    action = 'Sell'
    amt = -amt # now amt is < 0
    val = -val # now val is < 0
  elsif desc == 'Sold (Cancel)'
    action = 'Buy'
    amt = -amt # now amt is > 0
  elsif desc == 'Redemption' || desc == 'Automatic Redemption'
    action = 'Sell'
    memo = detail
    amt = -amt # now amt is < 0
    val = -val # now val is < 0
  elsif desc == 'Class Exchange'
    if amt < 0
      action = 'BuyXfr'
      amt = -amt # now amt is > 0
    else
      action = 'SellXfr'
      amt = -amt # now amt is < 0
      val = -val # now val is < 0
    end
  elsif desc == 'Branch Deposit' || desc == 'CASH TRANSFER' || desc == 'Transfer In' || desc == 'Cash in Lieu' # in MS file, val == 0
    action = 'Xfr'
    memo = detail
  elsif desc == 'Transfer(Long)' # in MS file, amt == 0
    if !detail.index('TRANSFER TO ') || detail.index('INSTRUCTIONS TO ').nil?
      action = 'BuyXfr'
    else
      action = 'SellXfr'
      val = -val # now val is < 0
    end
    memo = detail
  elsif desc == 'Rebate' || !desc.index('Capital Gain').nil? # in MS file, val == 0
    action = 'MiscInc'
    memo = detail
  elsif !desc.index('Capital Loss').nil? # in MS file, val == 0
    action = 'MiscExp'
    memo = detail
  elsif desc == 'Dividend' # in MS file, val == 0
    action = 'Dividend'
    memo = detail
  elsif desc == 'Dividend Stock' || desc == 'Split Receive' || desc == 'Reorg Receive' # in MS file, val > 0, amt == 0
    action = 'BuyXfr'
    memo = detail
  elsif desc == 'Distribution' # these seem only to be used with 'Split Receive'
    puts "line #{rownum} ignored: Distribution"
    return 0
  elsif desc == 'Reorg Deliver'
    if amt == 0  # val > 0, stock split - "sell" old shares
      val = - val # now val is < 0
      action = 'SellXfr'
    else # val == 0, amt >= 0 for cash in lieu of stock split 
      action = 'Xfr'
    end
  elsif desc == 'Interest' # in MS file, val == 0, amt >= 0
    if ticker_sym == 'MSBNK'
      action = 'Xfr' # Morgan Stanley bank interest
      memo = detail
    else 
      action = 'MiscInc' # Bond or other security interest
      memo = detail
    end
  elsif !desc.index('Fee').nil? # in MS file, val == 0, amt >= 0 for fee rebate, <= 0 for fee
    action = 'Xfr'
    memo = detail
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
import_file   = '/Users/pz/Documents/IRA.csv'
inv_acct_name = 'MS IRA'

inv_acct, xfr_acct, bank_acct = get_txn_accounts(inv_acct_name, 'Unassigned', 'MSBNK')
if !inv_acct
  puts "cannot verify - missing inv_acct"
else
  rv = 0
  verify_tickers(import_file, inv_acct, 'Symbol') do |tickers|
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
      rv = process_morgan_stanley_row(row, inv_acct, xfr_acct, bank_acct)
      rows += 1
    end
    puts "processed #{rows} rows"
  end
end
