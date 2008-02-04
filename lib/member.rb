require 'name'

class Member
  attr_reader :fromwhy, :fromdate, :name
  attr_accessor :id_person, :id_member
  
  # Sizes of small thumbnail pictures of members
  @@THUMB_WIDTH = 44
  @@THUMB_HEIGHT = 59

  def initialize(params)
    @id_member =    params[:id_member]
    @id_person =    params[:id_person]
    @house =        params[:house]
    @name =         params[:name]
    @constituency = params[:constituency]
    @party =        params[:party]
    @fromdate =     params[:fromdate]
    @todate =       params[:todate]
    @fromwhy =      params[:fromwhy]
    @towhy =        params[:towhy]
    @image_url =    params[:image_url]
    throw "Invalid keys" unless (params.keys -
      [:id_member, :id_person, :house, :name, :constituency, :party, :fromdate,
      :todate, :fromwhy, :towhy, :image_url]).empty?
  end
  
  def image(width, height)
    if @image_url
      conf = Configuration.new
      res = Net::HTTP::Proxy(conf.proxy_host, conf.proxy_port).get_response(@image_url)
      image = Magick::Image.from_blob(res.body)[0]
      image.resize_to_fit(width, height)
    end
  end
  
  def small_image
    image(@@THUMB_WIDTH, @@THUMB_HEIGHT)
  end
  
  def big_image
    image(@@THUMB_WIDTH * 2, @@THUMB_HEIGHT * 2)
  end
  
  def output_member(x)
    x.member(:id => "uk.org.publicwhip/member/#{@id_member}",
      :house => @house, :title => @name.title, :firstname => @name.first,
      :lastname => @name.last, :constituency => @constituency, :party => @party,
      :fromdate => @fromdate, :todate => @todate, :fromwhy => @fromwhy, :towhy => @towhy)
  end
  
  def output_person(x)
    x.person(:id => "uk.org.publicwhip/person/#{@id_person}", :latestname => @name.informal_name) do
      x.office(:id => "uk.org.publicwhip/member/#{@id_member}", :current => "yes")
    end
  end
end

# A collection of members
class Members
  attr_reader :members
  
  def initialize(members)
    @members = members
  end
  
  def Members.load(filename)
    doc = Hpricot(open("pwdata/members/all-members.xml"))
    Members.new(doc.search('member').map{|m| m.attributes})
  end

  def find_member_id_by_fullname(name)
    names = name.split(' ')
    names.delete("Mr")
    names.delete("Mrs")
    names.delete("Ms")
    names.delete("Dr")
    if names.size == 2
      firstname = names[0]
      lastname = names[1]
    elsif names.size == 1
      firstname = ""
      lastname = names[0]
    else
      throw "Can't parse the name #{name}"
    end
    find_member_id_by_name(firstname, lastname)
  end
  
  private
  
  def find_members_by_lastname(lastname)
    @members.find_all{|m| m["lastname"].downcase == lastname.downcase}
  end

  # If firstname is empty will just check by lastname
  def find_members_by_name(firstname, lastname)
    # First checking if there is an unambiguous match by lastname which allows
    # an amount of variation in first name: ie Tony vs Anthony
    matches = find_members_by_lastname(lastname)
    if firstname != "" && matches.size > 1
      matches = @members.find_all do |m|
        m["firstname"].downcase == firstname.downcase && m["lastname"].downcase == lastname.downcase
      end
    end
    matches
  end

  def find_member_id_by_name(firstname, lastname)
    matches = find_members_by_name(firstname, lastname)
    throw "More than one match for member based on first and last name" if matches.size > 1
    throw "No match for member found" if matches.size == 0
    matches[0]["id"]
  end
end