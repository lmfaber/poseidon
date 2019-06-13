#!/usr/bin/env ruby

require 'bio'
require 'mail'

require_relative 'sprichwort'

require 'encrypted_strings'

class FastaFormatChecker

  attr_accessor :fasta, :input_species, :continue, :mail_notes

  def initialize(fasta, new_fasta, internal2input_species, input2internal_species, log, project_dir)
    @fasta = fasta
    @new_fasta = new_fasta
    @internal2input_species = internal2input_species
    @input2internal_species = input2internal_species
    @continue = true
    @mail_notes = ''
    @log = log
    @project_dir = project_dir
  end

  def check(query_sequence_name, user_mail, timestamp, root_species)

    begin

      file = Bio::FastaFormat.open(@fasta)

      ids = []
      seqs = {}

      error_a = []

      nr_seqs = 0
      max_length = 0

      illegal_bases_seqs = {}

      file.each do |entry|

        nr_seqs += 1

        original_id = entry.definition
        id = original_id.split(' ')[0]
        id = id.gsub('.','_').gsub('-','_').gsub(':','_').gsub(',','_').gsub(';','_')
        id = id.upcase
        # remove tailing '_'
        if id.reverse.start_with?('_')
          id = id.scan(/./).reverse[1..id.length].reverse.join('')
        end

        @internal2input_species[id] = original_id
        @input2internal_species[original_id] = id

        # check for unique IDs in the fasta file
        if ids.include?(id)
          error_a.push("\nYour IDs are not unique. We only use your FASTA IDs until the first occurrence of a space character. Please check your FASTA file and try again. Duplicate ID: #{id}\n")
        else
          ids.push(id)
        end

        # check for non standard nucleotides in each sequence
        seq = Bio::Sequence::auto(entry.seq)

        # remove gap symbols '-' from seq
        if entry.seq.include?('-')
          seq = Bio::Sequence::auto(entry.seq.gsub('-',''))          
          @mail_notes << "\nPlease note, your sequence with ID #{entry.definition} does contain gap symbols: '-'. As PoSeiDon performs his own alignment, gap symbols were removed from your data.\n"
        end

        if seq.illegal_bases.length > 0 && seq.illegal_bases
          if seq.illegal_bases[0] == 'n' && seq.illegal_bases.length == 1
            # in this case, we just have some n in the sequence
            # check if the amount of Ns is above a certain threshold, if so, remove the full sequence
            percent_n = seq.count('n').to_f / seq.length
            if percent_n > 0.3
              illegal_bases_seqs[id] = "\nYour sequence with ID #{entry.definition} does contain to many ambiguous N bases. Found: #{(percent_n*100).round(2)}% N bases in this sequence. Please check!\n"
              @mail_notes << "\nPlease note, your sequence with ID #{entry.definition} does contain to many ambiguous N bases. Found: #{(percent_n*100).round(2)}% N bases in this sequence. We removed this entry from your input file to continue your PoSeiDon run!\n"
            else
              @mail_notes << "\nPlease note, your sequence with ID #{entry.definition} does contain 'N' values. We automatically remove columns from the final alignment containing 'N' bases.\n"
            end
          else
            illegal_bases_seqs[id] = "\nYour sequence with ID #{entry.definition} does contain nucleotide characters different from {A,C,G,T,U,N}. Found: #{seq.illegal_bases.join(',')}. Please check!\n"
            @mail_notes << "\nPlease note, your sequence with ID #{entry.definition} does contain nucleotide characters different from {A,C,G,T,U,N}. Found: #{seq.illegal_bases.join(',')}. We removed this entry from your input file to continue your PoSeiDon run!\n"
            next
          end
          #error_a.push("\nYour sequence with ID #{entry.definition} does contain nucleotide characters different from {A,C,G,T,U}. Found: #{seq.illegal_bases.join(',')}. Please check!\n")
        end

        # check for triplet code
        unless seq.length.modulo(3) == 0
          error_a.push("\nYour sequence with ID #{entry.definition} is not a correct coding sequence in the sense of following a correct triplet code.\n")
        end

        # check if multiple and internal stop codons are included
        if seq.illegal_bases.length == 0
          aa_seq = seq.translate
          if aa_seq.count('*') > 1 || (aa_seq.count('*') == 1 && aa_seq[aa_seq.length-1] != '*')
						illegal_bases_seqs[id] = "\nYour sequence with ID #{entry.definition} does contain multiple/internal stop codons. Please check!\n" unless illegal_bases_seqs.keys.include?(id)
            @mail_notes << "\nPlease note, your sequence with ID #{entry.definition} does contain multiple/internal stop codons. We removed this entry from your input file to continue your PoSeiDon run!\n"
            #error_a.push("\nYour sequence with ID #{entry.definition} does contain multiple/internal stop codons!\n")
          end
        end

        max_length = seq.length if seq.length > max_length

        seq = seq.upcase
        seqs[id] = seq.scan(/.{0,80}/).join("\n")

      end
      file.close
      
      # remove sequences with bad characters from the input file
      illegal_bases_seqs.keys.each do |id|
        puts "Remove #{id} from the input because of bad characters in the sequence."
        seqs.delete(id)
        nr_seqs -= 1
      end

      # check seq length
      if max_length > 20000
        error_a.push("\nPoSeiDon can only handle sequences with a maximum length of 20.000 nt. We detected a sequence with a length of #{max_length} nucleotides. Please reduce the size of your sequences and try again.\n")
      end

      # check how many sequences are included
      if nr_seqs > 100
        error_a.push("\nPoSeiDon can only handle up to 100 homologous sequences in one FASTA file. Your FASTA contains #{nr_seqs} sequence entries. Please reduce the amount of sequences and try again.\n")
      end

      if nr_seqs < 3
        error_a.push("\nPoSeiDon needs at least 3 homologous sequences as input. Your FASTA contains #{nr_seqs} sequence entries. Please add more sequences and try again.\n")
      end

      if seqs.keys.include?(query_sequence_name) && query_sequence_name.length > 0
        id = query_sequence_name
        seq = seqs[id]
        @new_fasta << ">#{id}\n#{seq}"
        seqs.each do |i, s|
          @new_fasta << ">#{i}\n#{s}" unless i == id
        end
      else
        if query_sequence_name.length > 0
          @mail_notes << "\nPlease note, the query sequence name you specified (#{query_sequence_name}) is not part of your FASTA file! Results will be based on the first FASTA ID occurring in your file.\n"
        end
        seqs.each do |id, seq|
          @new_fasta << ">#{id}\n#{seq}"
        end
      end

      root_species_mismatch = []
      root_species.each do |root_s|
        unless seqs.keys.include?(root_s)
          root_species_mismatch.push(root_s)
        end
      end

      if root_species_mismatch.size > 0
        @mail_notes << "\nPlease note, PoSeiDon was not able to find the following species IDs defined for tree rooting in your input FASTA file: #{root_species_mismatch.join(', ')}. Rerooting of the trees can not be performed on this species.\n"
        puts @mail_notes
      end

      bn = File.basename(@fasta)

      if error_a.size > 0
        send_mail(error_a.sort.uniq.join(''), user_mail, timestamp)
        @continue = false
        puts "There was a problem with the FASTA file (#{bn}), stop."
        @log << "There was a problem with the FASTA file (#{bn}), stop.\n"
        @log << error_a.sort.uniq.join('')
      else
        puts 'The input FASTA file seems to be valid. Continue...'
        @log << "The input FASTA file seems to be valid. Continue...\n"
      end

    rescue
      bn = File.basename(@fasta)
      puts "There was a more general problem with the Input file: #{bn}. Is it no FASTA?\n"
      file.close if file

      send_mail("\nPoSeiDon was not able to read your input file: #{bn}. Please check if your input is in valid FASTA format.", user_mail, timestamp)
      @new_fasta.close
      @continue = false
    end
  end

  def send_mail(message, user_mail, timestamp)

    options = { :address              => 'smtp.uni-jena.de',
                :port                 => 587,
                :domain               => 'prost.bioinf.minet.uni-jena.de',
                :user_name            => 'va93yit',
                :password             => 'na1GPmneDntAy96ry0pVzw==\n'.decrypt(:symmetric, :algorithm => 'des-ecb', :password => 'PoSeiDon'),
                :authentication       => 'plain',
                :enable_starttls_auto => true  }

    Mail.defaults do
      delivery_method :smtp, options
    end

    sw = Sprichwort.new


    # send mail with results link to user
    mail = mail(message, sw.sprichwort)

    if user_mail.size > 1
      Mail.deliver do
        from 'poseidon@uni-jena.de'
        to user_mail
        subject "Your PoSeiDon run #{timestamp}"
        body mail
      end
    end
    Mail.deliver do
      from 'poseidon@uni-jena.de'
      to 'martin.hoelzer@uni-jena.de'
      subject "A PoSeiDon run #{timestamp} was not finished for #{user_mail}"
      body mail
    end

  end

  def mail(error_message, sprichwort)
    message = <<MESSAGE_END
Dear user,

a problem occurred with your submitted FASTA file (#{File.basename(@fasta)}) on the PoSeiDon web service:

#########################################
#{error_message}
#########################################

Please note that the selection analysis requires coding nucleotide sequences with a correct open reading frame. Please check and upload your multiple FASTA file again: www.rna.uni-jena.de/poseidon

If you have any further problems, comments or feedback, don't hesitate to write me.

Thank you very much for using the PoSeiDon web service.

Cheers,
Martin

<><><><><><><><><><><><><><><><><><><><><><>
#{sprichwort}
<><><><><><><><><><><><><><><><><><><><><><>
MESSAGE_END
    message
  end

end
