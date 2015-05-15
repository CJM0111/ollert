require 'date'
require 'mongoid'
require 'awesome_print'

class ProgressChartsAnalyzer
  def self.analyze(data, startingList, endingList)
    return {} if data.nil? || data.empty?

    # open lists
    lists = data["lists"].select { |x| !x["closed"]}

    startingListIndex = lists.index{ |l| startingList == l["id"]} || 0
    endingListIndex = lists.index{ |l| endingList == l["id"]} || lists.count - 1

    cfdData = parse(data, lists)

    cfdData.reject do |date|
      index = lists.index{ |l| cfdData[date]["name"] == l["name"]}
      !index.nil? && index >= startingListIndex && index < endingListIndex
    end

    {
      cfd: formatCFD(cfdData, lists[startingListIndex..endingListIndex]),
      burnup: formatBurnUp(cfdData, lists[startingListIndex..endingListIndex-1], lists[endingListIndex, lists.count-1])
    }
  end

  private

  def self.parse(data, lists)
    card_actions = data["actions"].reject {|action| action["type"] == "updateList"}
    list_actions = data["actions"].select {|action| action["type"] == "updateList"}

    # open lists
    lists = data["lists"].select { |x| !x["closed"]}

    build(card_actions, lists)
  end

  def self.build(card_actions, open_lists)
    now = Time.now
    cfd = Hash.new do |h, k|
      h[k] = Hash[open_lists.collect { |list| [list["name"], []] }]
    end
    cfdpoints = Hash.new do |h, k|
      h[k] = Hash[open_lists.collect { |list| [list["name"], {}] }]
    end

    puts "Printing card actions, bout to go ham"
    ap card_actions

    isFirst = true
    cad = card_actions.group_by {|ca| ca["date"].to_date}
    return cfd if cad.empty?
    cad.keys.min.upto(Date.today).each do |date|

      cfd[date-1].each do |k,v|
        cfd[date][k] = v.clone
      end unless isFirst
      cfdpoints[date-1].each do |k,v|
        cfdpoints[date][k] = v.clone
      end unless isFirst
      isFirst = false

      next if cad[date].nil?
      cad[date].sort_by {|c| c["date"].to_datetime}.each do |action|
        data = action["data"]
        pointvalue = data["card"]["name"].scan(/(?:\d*\.)?\d+/)
        if pointvalue.length == 0
          data["card"]["points"] = 0.0
        else
          data["card"]["points"] = pointvalue[0].to_f
        end


        if action["type"] == "updateCard" && !data["listAfter"].nil? && !data["listBefore"].nil?
          list = data["listAfter"]

          matching_list = open_lists.select {|l| l["id"] == data["listBefore"]["id"]}.first
          unless matching_list.nil?
            cfd[date][matching_list["name"]].delete data["card"]["id"]
            cfdpoints[date][matching_list["name"]].delete data["card"]["id"]
            puts "Found an update: Printing cfdpoints[date][matching_list[name]] and class"
            puts "cfdpoints[date][matching_list[name]]"
            puts cfdpoints[date][matching_list["name"]]
            puts cfdpoints[date][matching_list["name"]].class
            puts "cfd[date][matching_list[name]]"
            puts cfd[date][matching_list["name"]]
            puts cfd[date][matching_list["name"]].class
            puts data["card"]["id"]

          end
        elsif action["type"] == "createCard"
          list = data["list"]
        else
          # card was closed
          list = cfd[date].select {|k,v| v.any? {|cid| cid == data["card"]["id"]}}
          unless list.nil? || list.count != 1
            cfd[date][list.keys.first].delete data["card"]["id"]
            #cfdpoints[date][list.keys.first].delete data["card"]["id"]
          end
          next
        end

        matching_list = open_lists.select {|l| l["id"] == list["id"]}.first
        next if matching_list.nil?
        next if cfd[date][matching_list["name"]].include? action["data"]["card"]["id"]
        next if cfdpoints[date][matching_list["name"]].include? action["data"]["card"]["id"]
        cfd[date][matching_list["name"]] << action["data"]["card"]["id"]
        idpoints = Hash.new()
        idpoints[action["data"]["card"]["id"]] = action["data"]["card"]["points"]
        puts cfdpoints[date][matching_list["name"]].class
        # cfdpoints[date][matching_list["name"]][action["data"]["card"]["id"]] = action["data"]["card"]["points"]

        print "Date: "
        puts date
        print "Action type was: "
        puts action["type"]
        print "Card id affected: "
        puts data["card"]["id"]
        puts "Final list: "
        ap list
        if action["type"] == "updateCard"
          print "Starting list: "
          ap open_lists.select {|l| l["id"] == data["listBefore"]["id"]}.first
        end


      end

    end

    ap cfd
    ap cfdpoints

    # What's been done here?
    # cfd holds the IDs of cards before getting squashed.
    # Once squashed, cfd becomes a hash using dates for keys and another hash we'll call V for values
    # V uses list names for keys and the amount of cards in that list as the values
    # cfdpoints, after squashing, becomes a hash very similar to cfd, but the values of V are the point values of the cards,
    # not their IDs.

    cfd.each {|k,v| v.each {|l,c| cfd[k][l] = c.count}}
    cfdpoints.keys.each do |date|
      lpoints = 0
      cfdpoints[date].keys.each do |l|
        cfdpoints[date][l].each do |id, p|
          lpoints += p
        end
        cfdpoints[date][l] = lpoints
      end
    end

    cfdpoints

  end

  def self.formatCFD(cfd, lists)
    dates = cfd.keys.sort
    cfd_values = Array.new
    lists.each do |list|
      list_array = Array.new
      dates.each do |date|
        list_array << [date.strftime('%s000').to_i, cfd[date][list["name"]]]
      end
      cfd_values << { name: list["name"], data: list_array}
    end

    {
      cfddata: cfd_values
    }
  end

  def self.formatBurnUp(cfd, inScopeLists, outOfScopeLists)
    dates = cfd.keys.sort


    cfd_values = Array.new
   
    inList_array = Array.new
    outList_array = Array.new
    dates.each do |date|
      inCount = 0
      outCount = 0

      inScopeLists.each do |list|
        inCount += cfd[date][list["name"]]
      end
      inList_array << [date.strftime('%s000').to_i, inCount]

      outOfScopeLists.each do |list|
        outCount += cfd[date][list["name"]]
      end
      outList_array << [date.strftime('%s000').to_i, outCount]
    end
    cfd_values << { name: "InScope", data: inList_array}
    cfd_values << { name: "Complete", data: outList_array}

    {
      cfddata: cfd_values
    }
  end
end
