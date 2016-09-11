require "rails_helper"

describe Agenda do
  subject(:agenda) { described_class.new }
  it { is_expected.to belong_to(:academic_degree_term) }
  it { is_expected.to have_one(:academic_degree).through(:academic_degree_term) }
  it { is_expected.to have_one(:term).through(:academic_degree_term) }
  it { is_expected.to have_many(:academic_degree_term_courses).through(:academic_degree_term) }
  it { is_expected.to have_many(:schedules).dependent(:delete_all) }

  it { is_expected.to serialize(:courses).as(AgendaCoursesSerializer) }
  it { is_expected.to serialize(:leaves).as(LeavesSerializer) }
  it { is_expected.to serialize(:mandatory_course_ids) }
  it { is_expected.to accept_nested_attributes_for_serialized(:leaves, attributes: { starts_at: 0, ends_at: 100 }) }

  it { is_expected.to validate_presence_of(:courses) }
  it { is_expected.to validate_inclusion_of(:courses_per_schedule).in_range(1..5) }
  it { is_expected.to validate_with(AgendaCoursesValidator) }

  its(:course_ids) { is_expected.to be_empty }
  its(:mandatory_course_ids) { is_expected.to be_empty }
  its(:courses_per_schedule) { is_expected.to eq(1) }
  its(:processing) { is_expected.to eq(false) }
  its(:token) { is_expected.to be_present }

  it { is_expected.to delegate_method(:empty?).to(:schedules) }
  it { is_expected.to delegate_method(:pruned).to(:courses).with_prefix }
  it { is_expected.to delegate_method(:mandatory).to(:courses).with_prefix }
  it { is_expected.to delegate_method(:remainder).to(:courses).with_prefix }
  it { is_expected.to delegate_method(:mandatory).to(:courses_pruned).with_prefix }
  it { is_expected.to delegate_method(:remainder).to(:courses_pruned).with_prefix }

  describe "#new" do
    its(:course_ids) { is_expected.to eq([]) }
    its(:courses_per_schedule) { is_expected.to eq(1) }
    its(:processing) { is_expected.to eq(false) }
    its(:token) { is_expected.not_to be_nil }
  end

  describe "#to_param" do
    before { agenda.token = "a_token" }

    it "aliases to #token" do
      expect(agenda.to_param).to eq("a_token")
    end
  end

  describe "#course_ids=" do
    let(:academic_degree_term) { create(:academic_degree_term) }
    let(:academic_degree_term_courses) do
      create_list(:academic_degree_term_course, 4, academic_degree_term: academic_degree_term)
    end
    let(:course_ids) { academic_degree_term_courses.collect(&:id) }
    let(:courses) { academic_degree_term_courses.collect { |course| AgendaCourse.from(course) } }

    context "from a new instance" do
      before do
        agenda.academic_degree_term = academic_degree_term
        agenda.save!(validate: false)
      end

      it "assigns the right courses" do
        expect { agenda.course_ids = course_ids }.to change { agenda.courses }.from([]).to(courses)
      end
    end

    context "from an instance derived of an academic_degree_term" do
      subject(:agenda) { academic_degree_term.agendas.new(course_ids: course_ids) }

      it "assigns the right courses" do
        expect(agenda.courses).to eq(courses)
      end
    end
  end

  describe "#course_ids" do
    let(:courses) { [AgendaCourse.new(id: 3), AgendaCourse.new(id: 9000)] }
    before { agenda.courses = courses }

    its(:course_ids) { is_expected.to eq([3, 9000]) }
  end

  describe "#courses" do
    subject(:agenda) { build(:agenda, mandatory_course_ids: [1, 2]) }
    let(:courses_collection) { instance_double(AgendaCourseCollection) }
    before do
      allow(AgendaCourseCollection)
        .to receive(:new).with(agenda.courses, agenda.mandatory_course_ids, agenda.leaves)
        .and_return(courses_collection)
    end

    its(:courses) { is_expected.to eq(courses_collection) }
  end

  describe "#combine" do
    subject(:agenda) { create(:combined_agenda) }

    it "resets the combined timestamp" do
      expect { agenda.combine }.to change { agenda.combined_at }.to(nil)
    end

    it "sets processing to true" do
      expect { agenda.combine }.to change { agenda.processing }.from(false).to(true)
    end

    context "when it was not able to save" do
      before { agenda.courses_per_schedule = 0 }

      specify { expect(agenda.combine).to eq(false) }
    end

    context "when it saved" do
      specify { expect(agenda.combine).to eq(true) }
    end
  end

  describe "#mark_as_finished_processing" do
    before do
      Timecop.freeze(2016, 1, 1)
      agenda.mark_as_finished_processing
    end
    after { Timecop.return }

    its(:processing) { is_expected.to eq(false) }
    its(:combined_at) { is_expected.to eq(Time.zone.now) }
  end

  describe "mandatory_course_ids=" do
    subject { build(:agenda, mandatory_course_ids: [nil, "1", "", "2"]) }

    its(:mandatory_course_ids) { [1, 2] }
  end

  describe "validating leaves" do
    context "when any leave is invalid" do
      before do
        agenda.leaves = [
          Leave.new(starts_at: 2000, ends_at: 1000),
          Leave.new(starts_at: 2000, ends_at: 1000),
        ]
        agenda.valid?
      end

      it "sets the agenda to be invalid" do
        expect(agenda).not_to be_valid
      end

      it "adds an error on agenda" do
        expect(agenda.errors).to be_added(:leaves, :invalid)
      end

      it "sets an error on leaves" do
        expect(agenda.leaves.all?(&:invalid?)).to eq(true)
      end
    end

    context "when all leaves are valid" do
      before { agenda.valid? }

      it "adds no errors on leaves" do
        expect(agenda.errors).not_to be_added(:leaves, :invalid)
      end
    end
  end

  define :validate_with do |validator|
    match do |actual|
      expect_any_instance_of(validator).to receive(:validate).with(actual)
      actual.valid?
      true
    end
  end
end
