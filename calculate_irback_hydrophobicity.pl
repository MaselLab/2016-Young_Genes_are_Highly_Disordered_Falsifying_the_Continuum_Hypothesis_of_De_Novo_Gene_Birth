#!/usr/local/bin/perl

#################################################################################
=head1 # CALCULATE IRBACK HYDROPHOBICITY ########################################
#################################################################################

=head2 AUTHOR: Scott Foy, Ph.D.

This program will calculate a hydrophobicity score for a given
protein sequence. The algorithm to calculate the hydrophobicity
score is in Irback (2000). This algorithm will calculate the hydrophobicity
score (M) and then divide it by length (N). 

Each polypeptide sequence will be extracted from a MySQL database. The
script will return the Irback hydrophobicity scores to the database. 

=head2 REQUIREMENTS:

This program requires the DBD::mysql module (and the
library [DBD::mysql directory]). Although DBD and DBI are both
part of the core modules, the DBD:mysql driver is not and must be
downloaded from CPAN.

The MySQL database does not need to be located on the computer
used to execute the script.

No protein unique ID may contain a space or tab.

#####################################################################
=head1 # ARGUMENTS ##################################################
#####################################################################

The hardcoded values below are the default values for each variable.
Additionally, below these are descriptions of each variable.

=head2 ARGUMENT VALUES

The following input variables are lexical and can be utilized
thoughout the entire CALCULATE_IRBACK_HYDROPHOBICITY program.

=cut

use warnings;
use strict;

my  ($mysql_extraction_query,
    $mysql_insertion_statement,
    $execute_iupred_command,
    
    $database_host_ip_address,
    $mysql_account_username,
    $mysql_account_password,
    $mysql_database_name,
    );

# Default Input MySQL Commands:
# ____________________________

$mysql_extraction_query = 'SELECT PrimaryKey, ProteinSequence FROM TableName'; 
$mysql_insertion_statement = 'UPDATE TableName SET IrbackHydrophobicityPerLength = ? WHERE PrimaryKey = ?';

# Default Database Information:
# ____________________________

$database_host_ip_address = '127.0.0.1'; # "localhost"
$mysql_account_username = ''; 
$mysql_account_password = ''; 
$mysql_database_name = ''; 

=head2 ARGUMENT DESCRIPTIONS

$mysql_extraction_query = This is the MySQL command that extracts data from
the MySQL database. This command should be input exactly as it would be
input into a MySQL command line interface. If the user wishes to calculate the
Irback hydrophobicity of only certain protein sequences, the user may add a
"WHERE" statement to the MySQL command. 

$mysql_insertion_statement = This is the MySQL command that inserts the various
Irback hydrophobicity scores back into the MySQL database. For the most part,
this command should be input exactly as it would be input into a MySQL command
line interface. However, the command requires 3 placeholders (question marks),
which translate into three bind values. The first placeholder is for the Irback
hydrophobicity scores (divided by the length of the protein). The second
placeholder is the unique ID so we know where to insert the hydrophobicity information.

$database_host_ip_address = This is the IP address of the computer hosting
the MySQL database. If the MySQL database is located on the local computer
that is executing this program, the IP address should be set as
"localhost" or "127.0.0.1". 

$mysql_account_username = This is the username required to access the MySQL
database. Importantly, this is NOT the username required to access the
remote computer. That is, this is the MySQL username, NOT the computer login
username.

$mysql_account_password = This is the password required to access the MySQL
database. Importantly, this is NOT the password required to access the
remote computer. That is, this is the MySQL password, NOT the computer login
password.

$mysql_database_name = This is the name of the MySQL database containing the
information to be extracted. This is also the database into which the newly
generated hydrophobicty information will be placed (i.e., the one containing the
output information from the bioinformatics program). 

=cut

#####################################################################
# PRIMARY PROGRAM ###################################################
#####################################################################

my  ($database_connection_object,
    $database_extraction_object,
    $database_insertion_object,
    $row_array,
    
    $sequence_uid,
    $protein_sequence,
    $hydrophobicity_score,
    );

# We must first access the MySQL database.

use DBI;

print 'Connecting to host database = ' . "$database_host_ip_address\n";

$database_connection_object = DBI->connect("dbi:mysql:$mysql_database_name;$database_host_ip_address",
                                           $mysql_account_username, $mysql_account_password);

print "Database connected\n";

# We now pre-prepare our MySQL commands that will be used to both
# extract and insert data.

$database_extraction_object = $database_connection_object->prepare($mysql_extraction_query);
$database_insertion_object = $database_connection_object->prepare($mysql_insertion_statement);

$database_extraction_object->execute();

print "Database extraction command executed\n";

while ($row_array = $database_extraction_object->fetchrow_arrayref)
    {
    # The $row_array is a reference to an array, each element of which
    # is a value from a row of the database. Specifically, each element
    # contains the value returned by the "SELECT" statement in the
    # $mysql_extraction_query.In this case, the zeroth
    # element is the PrimaryKey and the first element is the
    # ProteinSequence.
    
    $sequence_uid = $row_array->[0];
    $protein_sequence = $row_array->[1];

    undef $row_array;
    
    $hydrophobicity_score = &calculate_hydrophobicity($protein_sequence);
    
    # We must now insert the $hydrophobicity_score into the database for this specific row.
    
    $database_insertion_object->execute($hydrophobicity_score, $sequence_uid);
    
    undef $protein_sequence;
    undef $sequence_uid;
    };

$database_connection_object->disconnect;

no DBI;  

print "\nProgram finished";

exit;

####################################################################################
# SUBROUTINES ######################################################################
####################################################################################

# CALCULATE_HYDROPHOBICITY

# The following subroutine will calculate the Irback hydrophobicity
# scores for each amino acid. Input for the subroutine is a protein
# sequence. Output is a hydrophobicity score divided by the number
# of amino acids in the protein. 

sub calculate_hydrophobicity
    {
    
    # Input Variables
    
    my  ($protein_sequence) = @_;
    
    # Subroutine Variables

    my  (%hydrophobicity_score_vector,
        @protein_sequence_array,
        $hydrophobicity_score,
        );

    # The following hydrophobicity scores were obtained from:
    # http://blanco.biomol.uci.edu/hydrophobicity_scales.html
    
    %hydrophobicity_score_vector =
        (
        'A' =>  -1, 
        'R' =>  -1, 
        'N' =>  -1,
        'D' =>  -1, 
        'C' =>  -1,
        'Q' =>  -1, 
        'E' =>  -1, 
        'G' =>  -1,
        'H' =>  -1, 
        'I' => 1,
        'L' => 1, 
        'K' =>  -1, 
        'M' => 1, 
        'F' => 1, 
        'P' => -1, 
        'S' =>  -1, 
        'T' =>  -1, 
        'W' => 1, 
        'Y' =>  -1, 
        'V' => 1,
        'X' => 0,
        'U' => -1
        );

    $hydrophobicity_score = 0;

    @protein_sequence_array = split('', $protein_sequence);
    
    foreach (@protein_sequence_array)
        {
        $hydrophobicity_score = $hydrophobicity_score + $hydrophobicity_score_vector{$_};
        };
    
    undef @protein_sequence_array;
    
    $hydrophobicity_score = $hydrophobicity_score / length($protein_sequence);
    
    return $hydrophobicity_score;

    };

########################################################################################
