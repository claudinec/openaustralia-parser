$:.unshift "#{File.dirname(__FILE__)}/../lib"

require "test/unit"

require "hansard_division"
require 'hpricot'

describe HansardDivision do
  subject(:division) do
    # Tellers are indicated with a "*". There might be or might not be a space before the "*".
    HansardDivision.new(Hpricot.XML('
    <division>
			<division.header>
				<time.stamp>09:06:00</time.stamp>
				<para>The House divided.&#xA0;&#xA0;&#xA0;&#xA0; </para>
			</division.header>
			<para>(The Speaker&#x2014;Mr Harry Jenkins)</para>
			<division.data>
				<ayes>
					<num.votes>3</num.votes>
					<title>AYES</title>
					<names>
						<name>Joe Bloggs *</name>
						<name>Henry Smith</name>
						<name>Phil Smith*</name>
					</names>
				</ayes>
				<noes>
					<num.votes>1</num.votes>
					<title>NOES</title>
					<names>
						<name>John Smith *</name>
					</names>
				</noes>
			</division.data>
			<para>* denotes teller</para>
			<division.result>
				<para>Question agreed to.</para>
			</division.result>
		</division>'), "", "", nil)
  end
  
  it "should parse the xml for a division correctly" do
		# Note that the *'s are stripped from the names
		division.yes.should == ["Joe Bloggs", "Henry Smith", "Phil Smith"]
		division.no.should == ["John Smith"]
  end
  
  it "should know the time the division took place" do
		division.time.should == "09:06:00"
  end

  it "should recognise the tellers" do
    division.yes_tellers.should == ["Joe Bloggs", "Phil Smith"]
    division.no_tellers.should == ["John Smith"]
  end  

  describe '#result' do
    it { division.result.should eq(:yes) }
  end

  describe 'tied vote' do
    let(:old_tied_division_xml) do
      Hpricot.XML('
      <division>
        <division.header>
          <time.stamp>09:06:00</time.stamp>
          <para>The House divided.&#xA0;&#xA0;&#xA0;&#xA0; </para>
        </division.header>
        <para>(The Speaker&#x2014;Mr Harry Jenkins)</para>
        <division.data>
          <ayes>
            <num.votes>3</num.votes>
            <title>AYES</title>
            <names>
              <name>Bloggs, Joe*</name>
              <name>Smith, Henry</name>
              <name>Smith, Phil*</name>
            </names>
          </ayes>
          <noes>
            <num.votes>3</num.votes>
            <title>NOES</title>
            <names>
              <name>Smith, John*</name>
              <name>Doe, Jane</name>
              <name>Quitecontrary, Mary</name>
            </names>
          </noes>
        </division.data>
        <para>* denotes teller</para>
        <interjection>
          <talk.start>
            <talker>
              <name.id>10000</name.id>
              <name role="metadata">SPEAKER, The</name>
              <name role="display">The SPEAKER</name>
            </talker>
            <para>—I use my casting vote with the noes on the basis of precedents that indicate leaving propositions in their original state.</para>
          </talk.start>
        </interjection>
        <division.result>
          <para>Question negatived.</para>
        </division.result>
      </division>')
    end
    # There's a slightly different layout in newer XML
    let(:new_tied_division_xml) do
      Hpricot.XML('
      <division>
        <division.header>
          <body>
            <p class="HPS-DivisionPreamble">The House divided. [16:13]<br />(The Speaker—Ms Anna Burke)</p>
          </body>
        </division.header>
        <division.data>
          <ayes>
            <num.votes>3</num.votes>
            <title>AYES</title>
            <names>
              <name>Bloggs, Joe*</name>
              <name>Smith, Henry</name>
              <name>Smith, Phil*</name>
            </names>
          </ayes>
          <noes>
            <num.votes>3</num.votes>
            <title>NOES</title>
            <names>
              <name>Smith, John*</name>
              <name>Doe, Jane</name>
              <name>Quitecontrary, Mary</name>
            </names>
          </noes>
         </division.data>
        <division.result>
          <body>
            <p class="HPS-DivisionFooter">The numbers for the ayes and the noes being equal, the Speaker gave her casting vote with the noes.<br />Question negatived.</p>
          </body>
        </division.result>
      </division>')
    end

    it "should include the speaker's casting vote in the event of a tie" do
      HansardDivision.new(old_tied_division_xml, "", "", nil).no.should == ["Smith, John", "Doe, Jane", "Quitecontrary, Mary", "Jenkins, Mr Harry"]
      HansardDivision.new(new_tied_division_xml, "", "", nil).no.should == ["Smith, John", "Doe, Jane", "Quitecontrary, Mary", "Burke, Ms Anna"]
    end

    describe '#tied?' do
      it { HansardDivision.new(old_tied_division_xml, "", "", nil).tied?.should be_true }
      it { HansardDivision.new(new_tied_division_xml, "", "", nil).tied?.should be_true }
    end

    describe '#result' do
      it { HansardDivision.new(old_tied_division_xml, "", "", nil).result.should eq(:no) }
      it { HansardDivision.new(new_tied_division_xml, "", "", nil).result.should eq(:no) }
    end

    describe '#speaker' do
      it { HansardDivision.new(old_tied_division_xml, "", "", nil).speaker.should eq('Jenkins, Mr Harry') }
      it { HansardDivision.new(new_tied_division_xml, "", "", nil).speaker.should eq('Burke, Ms Anna') }
    end

    it "should not include speaker's vote in Senate divisions" do
      pending
    end

    it "should raise an error if we can determine casting vote in the lower house" do
      pending
    end
  end
end

describe HansardDivision, "with pairings" do
  before(:each) do
    @division = HansardDivision.new(Hpricot.XML(
      '<division>
          <division.header>
              <time.stamp>10:36:00</time.stamp>
              <para>The Senate divided.&#xA0;&#xA0;&#xA0;&#xA0; </para>
          </division.header>
          <para>(The President&#x2014;Senator the Hon. JJ Hogg)</para>
          <division.data>
              <pairs>
                  <num.votes>2</num.votes>
                  <title>PAIRS</title>
                  <names>
                      <name>Lundy, K.A.</name>
                      <name>McGauran, J.J.J.</name>
                      <name>Stephens, U.</name>
                      <name>Barnett, G.</name>
                  </names>
              </pairs>
          </division.data>
          <para>* denotes teller</para>
          <division.result>
              <para>Question negatived.</para>
          </division.result>
      </division>'), "", "", nil)
  end

  it "should parse the pairs votes" do
    @division.pairs.should == [["Lundy, K.A.", "McGauran, J.J.J."], ["Stephens, U.", "Barnett, G."]]
  end

  describe "with no timestamp but a time in the preamble" do

    let(:division_without_timestamp) do
      HansardDivision.new(Hpricot.XML('
    <division>
			<division.header>
         <body>
           <p class="HPS-DivisionPreamble">The House divided. [09:32]<br />(The Speaker—Ms Anna Burke)</p>
         </body>
			</division.header>
			<para>(The Speaker&#x2014;Mr Harry Jenkins)</para>
			<division.data>
				<ayes>
					<num.votes>3</num.votes>
					<title>AYES</title>
					<names>
						<name>Joe Bloggs *</name>
						<name>Henry Smith</name>
						<name>Phil Smith*</name>
					</names>
				</ayes>
				<noes>
					<num.votes>1</num.votes>
					<title>NOES</title>
					<names>
						<name>John Smith *</name>
					</names>
				</noes>
			</division.data>
			<para>* denotes teller</para>
			<division.result>
				<para>Question agreed to.</para>
			</division.result>
		</division>'), "", "", nil)
    end

    it "should correctly extract the time" do
      division_without_timestamp.time.should == '09:32'
    end
  end
end
