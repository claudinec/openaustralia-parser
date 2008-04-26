require 'rubygems'
gem 'mechanize', "= 0.6.10"
require 'mechanize'
require 'RMagick'

require 'configuration'

class PeopleImageDownloader
  @@SMALL_THUMBNAIL_WIDTH = 44
  @@SMALL_THUMBNAIL_HEIGHT = 59

  def initialize
    # Required to workaround long viewstates generated by .NET (whatever that means)
    # See http://code.whytheluckystiff.net/hpricot/ticket/13
    Hpricot.buffer_size = 262144

    @conf = Configuration.new
    @agent = WWW::Mechanize.new
    @agent.set_proxy(@conf.proxy_host, @conf.proxy_port)
  end
  
  def download(people, small_image_dir, large_image_dir)
    # Clear out old photos
    system("rm -rf #{small_image_dir}/*.jpg #{large_image_dir}/*.jpg")

    each_person_bio_page do |page|
      name, image = extract_name_and_image_from_page(page)
      # Small HACK - removing title of name
      name = Name.new(:first => name.first, :nick => name.nick, :middle => name.middle, :last => name.last, :post_title => name.post_title) if name
      if name
        person = people.find_person_by_name(name)
        if person
          image.resize_to_fit(@@SMALL_THUMBNAIL_WIDTH, @@SMALL_THUMBNAIL_HEIGHT).write(small_image_dir + "/#{person.id.count}.jpg")
          image.resize_to_fit(@@SMALL_THUMBNAIL_WIDTH * 2, @@SMALL_THUMBNAIL_HEIGHT * 2).write(large_image_dir + "/#{person.id.count}.jpg")
        else
          puts "WARNING: Skipping photo for #{name.full_name} because they don't exist in the list of people"
        end
      end
    end
  end
  
  def each_person_bio_page
    # Iterate over current members of house
    @agent.get(@conf.current_house_members_url).links[29..-4].each do |link|
      @agent.transact {yield @agent.click(link)}
    end
    # Iterate over current members of senate
    @agent.get(@conf.current_senate_members_url).links[29..-4].each do |link|
      @agent.transact {yield @agent.click(link)}
    end
    # Iterate over former members of house and senate
    @agent.get(@conf.former_members_house_and_senate_url).links[29..-4].each do |link|
      @agent.transact {yield @agent.click(link)}
    end    
  end
  
  def extract_name_and_image_from_page(page)
    name = Name.last_title_first(page.search("#txtTitle").inner_text.to_s[14..-1])
    content = page.search('div#contentstart')  
    img_tag = content.search("img").first
    if img_tag
      relative_image_url = img_tag.attributes['src']
      if relative_image_url != "images/top_btn.gif"
        url = page.uri + URI.parse(relative_image_url)
        conf = Configuration.new
        res = Net::HTTP::Proxy(conf.proxy_host, conf.proxy_port).get_response(url)
        begin
          return name, Magick::Image.from_blob(res.body)[0]
        rescue RuntimeError, Magick::ImageMagickError
          puts "WARNING: Could not load image for #{name.informal_name} at #{url}"
        end
      end
    end
  end
end
