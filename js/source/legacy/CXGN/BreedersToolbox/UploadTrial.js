/*jslint browser: true, devel: true */

/**

=head1 UploadTrial.js

Dialogs for uploading trials


=head1 AUTHOR

Jeremy D. Edwards <jde22@cornell.edu>

=cut

*/

var $j = jQuery.noConflict();
// const TRIAL_SYNONYM_SEARCH_HOST = "https://synonyms.triticeaetoolbox.org";
const TRIAL_SYNONYM_SEARCH_HOST = "http://localhost:3000";

jQuery(document).ready(function ($) {

    var trial_id;
    var plants_per_plot;
    var inherits_plot_treatments;
    jQuery('#upload_trial_trial_sourced').change(function(){
        if(jQuery(this).val() == 'yes'){
            jQuery('#upload_trial_source_trial_section').show();
        } else {
            jQuery('#upload_trial_source_trial_section').hide();
        }
    });

    jQuery('#trial_upload_breeding_program').change(function(){
        populate_upload_trial_linkage_selects();
    });

    function populate_upload_trial_linkage_selects(){
        get_select_box('trials', 'upload_trial_trial_source', {'id':'upload_trial_trial_source_select', 'name':'upload_trial_trial_source_select', 'breeding_program_name':jQuery('#trial_upload_breeding_program').val(), 'multiple':1, 'empty':1} );
    }

    function upload_trial_validate_form(){
        var trial_name = $("#trial_upload_name").val();
        var breeding_program = $("#trial_upload_breeding_program").val();
        var location = $("#trial_upload_location").val();
        var trial_year = $("#trial_upload_year").val();
        var description = $("#trial_upload_description").val();
        var design_type = $("#trial_upload_design_method").val();
        var uploadFile = $("#trial_uploaded_file").val();
        var trial_stock_type = $("#trial_upload_trial_stock_type").val();
        var plot_width = $("#trial_upload_plot_width").val();
        var plot_length = $("#trial_upload_plot_length").val();
        plants_per_plot = $("#trial_upload_plant_entries").val();
        inherits_plot_treatments = $('#trial_upload_plants_per_plot_inherit_treatments').val();


        if (trial_name === '') {
            alert("Please give a trial name");
        }
        else if (breeding_program === '') {
            alert("Please give a breeding program");
        }
        else if (location === '') {
            alert("Please give a location");
        }
        else if (trial_year === '') {
            alert("Please give a trial year");
        }
        else if (plot_width < 0 ){
            alert("Please check the plot width");
        }
        else if (plot_width > 13){
            alert("Please check the plot width is too high");
        }
        else if (plot_length < 0){
            alert("Please check the plot length");
        }
        else if (plot_length > 13){
            alert("Please check the plot length is too high");
        }
        else if (plants_per_plot > 500) {
            alert("Please no more than 500 plants per plot.");
        }
        else if (description === '') {
            alert("Please give a description");
        }
        else if (trial_stock_type === '') {
            alert("Please select stock type being evaluated in trial");
        }
        else if (design_type === '') {
            alert("Please give a design type");
        }
        else if (uploadFile === '') {
            alert("Please select a file");
        }
        else {
            verify_upload_trial_name(trial_name);
        }
    }

    function verify_upload_trial_name(trial_name){
        jQuery.ajax( {
            url: '/ajax/trial/verify_trial_name?trial_name='+trial_name,
            beforeSend: function() {
                jQuery("#working_modal").modal("show");
            },
            success: function(response) {
                console.log(response);
                jQuery("#working_modal").modal("hide");
                if (response.error){
                    alert(response.error);
                    jQuery('[name="upload_trial_submit_first"]').attr('disabled', true);
                    jQuery('[name="upload_trial_submit_second"]').attr('disabled', true);
                }
                else {
                    jQuery('[name="upload_trial_submit_first"]').attr('disabled', false);
                    jQuery('[name="upload_trial_submit_second"]').attr('disabled', false);
                }
            },
            error: function(response) {
                jQuery("#working_modal").modal("hide");
                alert('An error occurred checking trial name');
            }
        });
    }

    function upload_trial_file() {
        $('#upload_trial_form').attr("action", "/ajax/trial/upload_trial_file");
        $("#upload_trial_form").submit();
    }

    function upload_multiple_trial_designs_file() {
      $("multi_trial_synonym_search_replacements").val('');
      $("#upload_multiple_trials_warning_messages").html('');
      $("#upload_multiple_trials_error_messages").html('');
      $("#upload_multiple_trials_success_messages").html('');
      $('#upload_multiple_trial_designs_form').attr("action", "/ajax/trial/upload_multiple_trial_designs_file");
      $("#upload_multiple_trial_designs_form").submit();
  }


    function open_upload_trial_dialog() {
        $('#upload_trial_dialog').modal("show");
        //add a blank line to design method select dropdown that dissappears when dropdown is opened
        $("#trial_upload_design_method").prepend("<option value=''></option>").val('');
        $("#trial_upload_design_method").one('mousedown', function () {
            $("option:first", this).remove();
            $("#trial_design_more_info").show();
            //trigger design method change events in case the first one is selected after removal of the first blank select item
            $("#trial_upload_design_method").change();
        });

        //reset previous selections
        $("#trial_upload_design_method").change();
    }

    function add_plants_per_plot() {
        if (plants_per_plot && plants_per_plot != 0) {
            jQuery.ajax( {
                url: '/ajax/breeders/trial/'+trial_id+'/create_plant_entries/',
                type: 'POST',
                data: {
                    'plants_per_plot' : plants_per_plot,
                    'inherits_plot_treatments' : inherits_plot_treatments,
                },
                success: function(response) {
                    console.log(response);
                    if (response.error) {
                    alert(response.error);
                    }
                    else {
                    jQuery('#add_plants_dialog').modal("hide");
                    }
                },
                error: function(response) {
                    alert(response);
                },
                });
        }
    }


    $('[name="upload_trial_link"]').click(function () {
        get_select_box('years', 'trial_upload_year', {'auto_generate': 1 });
        get_select_box('trial_types', 'trial_upload_trial_type', {'empty': 1 });
        populate_upload_trial_linkage_selects();
        open_upload_trial_dialog();
    });

    $('#upload_trial_validate_form_button').click(function(){
        upload_trial_validate_form();
    });

    $('[name="upload_trial_submit_first"]').click(function () {
        upload_trial_file();
    });

    $('[name="upload_trial_submit_second"]').click(function () {
        upload_trial_file();
    });

    $('#multiple_trial_designs_upload_submit').click(function () {
      console.log("Registered click on multiple_trial_designs_upload_submit button");
        upload_multiple_trial_designs_file();
    });

    $("#upload_single_trial_design_format_info").click( function () {
        $("#trial_upload_spreadsheet_info_dialog" ).modal("show");
    });

    $("#upload_multiple_trial_designs_format_info").click( function () {
        $("#multiple_trial_upload_spreadsheet_info_dialog" ).modal("show");
    });

    $('#upload_trial_form').iframePostForm({
        json: true,
        post: function () {
            var uploadedTrialLayoutFile = $("#trial_uploaded_file").val();
            $('#working_modal').modal("show");
            if (uploadedTrialLayoutFile === '') {
                $('#working_modal').modal("hide");
                alert("No file selected");
                return;
            }
        },
        complete: function (response) {
            trial_id = response.trial_id;
            console.log(response);

            $('#working_modal').modal("hide");
            if (response.error) {
                alert(response.error);
                return;
            }
            else if (response.error_string) {

                if (response.missing_accessions) {
                    jQuery('#upload_trial_missing_accessions_div').show();
                    var missing_accessions_html = "<div class='well well-sm'><h3>Add the missing accessions to a list</h3><div id='upload_trial_missing_accessions' style='display:none'></div><div id='upload_trial_add_missing_accessions'></div></div><br/>";
                    $("#upload_trial_add_missing_accessions_html").html(missing_accessions_html);

                    var missing_accessions_vals = '';
                    for(var i=0; i<response.missing_accessions.length; i++) {
                        missing_accessions_vals = missing_accessions_vals + response.missing_accessions[i] + '\n';
                    }
                    $("#upload_trial_missing_accessions").html(missing_accessions_vals);
                    addToListMenu('upload_trial_add_missing_accessions', 'upload_trial_missing_accessions', {
                        selectText: true,
                        listType: 'accessions'
                    });
                } else {
                    jQuery('#upload_trial_missing_accessions_div').hide();
                    var no_missing_accessions_html = '<button class="btn btn-primary" onclick="Workflow.skip(this);">There were no errors regarding missing accessions Click Here</button><br/><br/>';
                    jQuery('#upload_trial_no_error_messages_html').html(no_missing_accessions_html);
                    Workflow.skip('#upload_trial_missing_accessions_div', false);
                }

                if (response.missing_seedlots) {
                    jQuery('#upload_trial_missing_seedlots_div').show();
                } else {
                    jQuery('#upload_trial_missing_seedlots_div').hide();
                    var no_missing_seedlot_html = '<button class="btn btn-primary" onclick="Workflow.skip(this);">There were no errors regarding missing seedlots Click Here</button><br/><br/>';
                    jQuery('#upload_trial_no_error_messages_seedlot_html').html(no_missing_seedlot_html);
                    Workflow.skip('#upload_trial_missing_seedlots_div', false);
                }

                $("#upload_trial_error_display tbody").html(response.error_string);
                //$("#upload_trial_error_display_seedlot tbody").html(response.error_string);
                $("#upload_trial_error_display_second_try").show();
                $("#upload_trial_error_display_second_try tbody").html(response.error_string);
            }
            if (response.missing_accessions){
                Workflow.focus("#trial_upload_workflow", 4);
            } else if(response.missing_seedlots){
                Workflow.focus("#trial_upload_workflow", 5);
            } else if(response.error_string){
                Workflow.focus("#trial_upload_workflow", 6);
                $("#upload_trial_error_display_second_try").show();
            }
            if (response.warnings) {
                alert(response.warnings);
            }
            if (response.success) {
                refreshTrailJsTree(0);
                jQuery("#upload_trial_error_display_second_try").hide();
                jQuery('#trial_upload_show_repeat_upload_button').hide();
                jQuery('[name="upload_trial_completed_message"]').html('<button class="btn btn-primary" name="upload_trial_success_complete_button">The trial was saved to the database with no errors! Congrats Click Here</button><br/><br/>');
                Workflow.skip('#upload_trial_missing_accessions_div', false);
                Workflow.skip('#upload_trial_missing_seedlots_div', false);
                Workflow.skip('#upload_trial_error_display_second_try', false);
                Workflow.focus("#trial_upload_workflow", -1); //Go to success page
                Workflow.check_complete("#trial_upload_workflow");
                add_plants_per_plot();
            }
        }
    });

    $('#upload_multiple_trial_designs_form').iframePostForm({
        json: true,
        post: function () {
            var uploadedTrialLayoutFile = $("#multiple_trial_designs_upload_file").val();
            $('#working_modal').modal("show");
            if (uploadedTrialLayoutFile === '') {
                $('#working_modal').modal("hide");
                alert("No file selected");
                return;
            }
        },
        complete: function(response) {
            console.log(response);
            $('#working_modal').modal("hide");

            if (response.warnings) {
                warnings = response.warnings;
                warning_html = "<li>"+warnings.join("</li><li>")+"</li>"
                $("#upload_multiple_trials_warning_messages").show();
                $("#upload_multiple_trials_warning_messages").html('<b>Warnings. Fix or ignore the following warnings and try again.</b><br><br>'+warning_html);
                return;
            }
            if (response.errors) {
                errors = response.errors;
                if (Array.isArray(errors)) {
                    error_html = "<li>"+errors.join("</li><li>")+"</li>";
                } else {
                    error_html = "<li>"+errors+"</li>";
                }
                $("#upload_multiple_trials_error_messages").show();
                $("#upload_multiple_trials_error_messages").html('<b>Errors found. Fix the following problems and try again.</b><br><br>'+error_html);
                return;
            }
            if ( response.synonym_search_check ) {
                let terms = [];
                if ( response && response.parsed_data ) {
                    for ( let trial in response.parsed_data ) {
                        if ( response.parsed_data.hasOwnProperty(trial) ) {
                            for ( let plot_number in response.parsed_data[trial].design_details ) {
                                let plot = response.parsed_data[trial].design_details[plot_number];
                                let accession_name = plot.stock_name;
                                if ( accession_name && !terms.includes(accession_name) ) {
                                    terms.push(accession_name);
                                }
                            }
                        }
                    }
                }
                if ( response.synonym_search_update ) {
                    trial_update_synonym_search_cache(terms);
                }
                else {
                    trial_perform_synonym_search(terms);
                }
            }
            if (response.success) {
                console.log("Success!!");
                refreshTrailJsTree(0);
                $("#upload_multiple_trials_success_messages").show();
                $("#upload_multiple_trials_success_messages").html("Success! All trials successfully loaded.");
                $("#multiple_trial_designs_upload_submit").hide();
                $("#upload_multiple_trials_success_button").show();
                return;
            }
        },
        error: function(response) {
            jQuery("#working_modal").modal("hide");
            $("#upload_multiple_trials_error_messages").html("An error occurred while trying to upload this file. Please check the formatting and try again");
            return;
        }
    });

    jQuery('#upload_multiple_trials_success_button').on('click', function(){
        //alert('Trial was saved in the database');
        jQuery('#upload_trial_dialog').modal('hide');
        location.reload();
    });

    jQuery(document).on('click', 'button[name="upload_trial_success_complete_button"]', function(){
        //alert('Trial was saved in the database');
        jQuery('#upload_trial_dialog').modal('hide');
        location.reload();
    });


    trial_check_synonym_search_cache();

});


/**
 * Check if this server is cached by the Synonym Search Tool
 * - Display the Date of the last cache update
 */
 function trial_check_synonym_search_cache() {
    jQuery.ajax({
        type: 'GET',
        url: `${TRIAL_SYNONYM_SEARCH_HOST}/api/cache?address=${location.protocol}//${location.host}/brapi/v1/`,
        dataType: "json",
        success: function(response) {
            if ( response && response.response && response.response.saved ) {
                jQuery(".trial_synonym_search_tool_last_updated").html(
                    new Date(response.response.saved).toLocaleString()
                );
            }
        },
        error: function() {
            jQuery(".trial_synonym_search_tool_last_updated").html("<em>Cache does not exist</em>");
            jQuery("#multi_trial_synonym_search_update").attr("checked", true);
        }
    });
}

/**
 * Update the Synonym Search Tool's cache of this server
 * - Monitor the progress of the update
 * - Perform a search of the specified terms when complete
 * @param {String[]} terms Search Terms (User's Accession Names)
 */
function trial_update_synonym_search_cache(terms) {

    // Display the dialog
    jQuery("#trial_synonym_search_dialog_starting").show();
    jQuery("#trial_synonym_search_dialog_working").hide();
    jQuery("#trial_synonym_search_dialog_results").hide();
    jQuery("#trial_synonym_search_dialog_continue").attr("disabled", true);
    jQuery("#trial_synonym_search_dialog").modal("show");

    // Start the Update
    let body = {
        address: `${location.protocol}//${location.host}/brapi/v1/`,
        version: "v1.3",
        auth_token: "",
        call_limit: 10
    }
    jQuery.ajax({
        type: 'PUT',
        url: `${TRIAL_SYNONYM_SEARCH_HOST}/api/cache`,
        dataType: "json",
        contentType: "application/json",
        data: JSON.stringify(body),
        success: function (response) {
            if ( response && response.status && response.status === 'queued' ) {
                trial_monitor_synonym_search(response.job.id, function() {
                    trial_perform_synonym_search(terms);
                });
            }
            else {
                alert("ERROR: Could not update synonym search cache!");
                jQuery("#trial_synonym_search_dialog_continue").attr("disabled", false);
            }
        },
        error: function () {
            alert("ERROR: Could not update synonym search cache!");
            jQuery("#trial_synonym_search_dialog_continue").attr("disabled", false);
        }
    });

}


/**
 * Perform a search using the specified terms
 * - Monitor the progress of the search
 * - Display the results when complete
 * @param {String[]} terms Search Terms (User's Accession Names)
 */
 function trial_perform_synonym_search(terms) {

    // Display the dialog
    jQuery("#trial_synonym_search_dialog_starting").show();
    jQuery("#trial_synonym_search_dialog_working").hide();
    jQuery("#trial_synonym_search_dialog_results").hide();
    jQuery("#trial_synonym_search_dialog_continue").attr("disabled", true);
    jQuery("#trial_synonym_search_dialog").modal("show");

    // Start the Search
    let body = {
        database: {
            address: `${location.protocol}//${location.host}/brapi/v1/`,
            version: "v1.3",
            auth_token: "",
            call_limit: 10
        },
        terms: terms,
        config: {
            database_terms: {
                name: true,
                synonyms: true,
                accession_numbers: true
            },
            search_routines: {
                name: true,
                punctuation: true,
                substring: true,
                prefix: false,
                edit_distance: false
            },
            return_records: false,
            case_sensitive: true
        }
    }
    jQuery.ajax({
        type: 'POST',
        url: `${TRIAL_SYNONYM_SEARCH_HOST}/api/search`,
        dataType: "json",
        contentType: "application/json",
        data: JSON.stringify(body),
        success: function (response) {
            if ( response && response.status && response.status === 'queued' ) {
                trial_monitor_synonym_search(response.job.id, function(response) {
                    trial_display_synonym_search(response);
                });
            }
            else {
                alert("ERROR: Could not start synonym search!");
                jQuery("#trial_synonym_search_dialog_continue").attr("disabled", false);
            }
        },
        error: function () {
            alert("ERROR: Could not start synonym search!");
            jQuery("#trial_synonym_search_dialog_continue").attr("disabled", false);
        }
    });

    // Continue with the accession upload
    jQuery("#trial_synonym_search_dialog_continue").off('click').on('click', trial_complete_synonym_search);

}



/**
 * Monitor the status of the specified job (cache update or search)
 * @param {String} job Job ID
 * @param {Function} callback Callback function(response)
 * @param {int} [count=0] Counter of the number of times the job is checked 
 */
 function trial_monitor_synonym_search(job, callback, count=0) {

    // Get current status of Job
    jQuery.ajax({
        type: 'GET',
        url: `${TRIAL_SYNONYM_SEARCH_HOST}/api/job/${job}?results=true`,
        dataType: "json",
        success: function (response) {
            
            // Job is pending/running --> continue checking status
            if ( response && response.status && (response.status === 'pending' || response.status === 'running') ) {
                if ( response.job.message ) {
                    jQuery("#trial_synonym_search_dialog_working_message").html(`<strong>${response.job.message.title}</strong><br />${response.job.message.subtitle}`);
                }
                if ( response.job.progress ) {
                    jQuery("#trial_synonym_search_dialog_working_progress").css("width", response.job.progress + '%');
                }
                jQuery("#trial_synonym_search_dialog_starting").hide();
                jQuery("#trial_synonym_search_dialog_working").show();
                jQuery("#trial_synonym_search_dialog_results").hide();
                setTimeout(function() {
                    trial_monitor_synonym_search(job, callback, count+1);
                }, 500+(250*count));
            }

            // Job is complete --> send the results to the callback
            else if ( response && response.status && response.status === 'complete' ) {
                return callback(response);
            }

            // Job status is unknown --> error
            else {
                alert("ERROR: Could not get search results!");
                jQuery("#trial_synonym_search_dialog_continue").attr("disabled", false);
            }

        },
        error: function () {
            alert("ERROR: Could not get search results!");
            jQuery("#trial_synonym_search_dialog_continue").attr("disabled", false);
        }
    });

}


/**
 * Display the results of the Synonym Search
 * - Build a table that displays potential matches
 * @param {Object} response Search Results
 */
function trial_display_synonym_search(response) {

    // Sort search terms
    let search_terms = Object.keys(response.job.results);
    search_terms.sort();

    // Parse the results
    let html = "<table class='table table-bordered table-hover'>";
    html += "<thead><tr><th>Your Accession Name</th><th>Match Type<th>Database Matches</th></tr></thead>";
    html += "<tbody>";
    for ( let st of search_terms ) {
        let results = response.job.results[st];
        let search_term = results.search_term;
        let exact_match = results.exact_match;
        let matches = results.matches;
        let match_count = Object.keys(matches).length;

        // Set match type
        let match_key = "";
        let match_type = "";
        let match_icon = "";
        if ( match_count === 0 ) {
            match_key = "none";
            match_type = "None";
            match_icon = "<span class='glyphicon glyphicon-minus-sign' style='color: #a94442'></span>";
        }
        else if ( exact_match && match_count === 1 ) {
            match_key = "exact";
            match_type = "Exact";
            match_icon = "<span class='glyphicon glyphicon-ok-sign' style='color: #3c763d'></span>";
        }
        else if ( exact_match && match_count > 1 ) {
            match_key = "exact_potential";
            match_type = "Exact &amp; Potential";
            match_icon = "<span class='glyphicon glyphicon-plus-sign' style='color: #3c763d'></span>";
        }
        else if ( match_count > 0 ) {
            match_key = "potential";
            match_type = "Potential";
            match_icon = "<span class='glyphicon glyphicon-question-sign' style='color: #8a6d3b'></span>";
        }

        // Build Results row
        html += "<tr class='match-row match-row-" + match_key + "'>";
        html += "<td>" + search_term + "</td>";

        // Match Type
        html += "<td>" + match_icon + "&nbsp;&nbsp;" + match_type + "</td>";

        // Display the matches
        html += "<td>";
        for ( let db_term of Object.keys(matches) ) {
            let match = matches[db_term];
            let selected = exact_match && exact_match === db_term ? 'checked' : '';
            html += "<input class='synonym_search_radio' type='radio' name='" + search_term + "' value='" + db_term + "' data-stock-id='" + match.germplasmDbId + "' " + selected + ">&nbsp;&nbsp;";
            html += "<a href='/stock/" + match.germplasmDbId + "/view' target='_blank'><strong>" + match.germplasmName + ":</strong></a>";
            html += "<ul>";
            for ( let i = 0; i < match.matched_db_terms.length; i++ ) {
                let d = match.matched_db_terms[i];
                html += "<li>";
                html += d.db_term.term + "&nbsp;";
                html += "(" + d.db_term.type + ")&nbsp;";
                html += (d.search_routine.key === 'exact' ? '<strong>' : '') + "(" + d.search_routine.name + ")" + (d.search_routine.key === 'exact' ? '</strong>' : '');
                html += "</li>";
            }
            html += "</ul>";
        }

        // No exact match found, create new entry
        if ( !exact_match || match_count === 0 ) {
            html += "<input class='synonym_search_radio' type='radio' name='" + search_term + "' value='' data-stock-id='' checked>&nbsp;&nbsp;";
            html += "<em>Create New Accession Entry</em>";
        }

        html += "</td>";
        html += "</tr>";
    }
    html += "</tbody>";
    html += "</html>";

    jQuery("#trial_synonym_search_dialog_results_table").html(html);
    jQuery(".match-row-exact").hide();
    if ( jQuery(".match-row-exact_potential,.match-row-potential,.match-row-none").length === 0 ) {
        jQuery("#trial_synonym_search_dialog_results_none").show();
    }

    jQuery('.synonym_search_dialog_filter').off('click').on('click', trial_toggle_match_type);

    jQuery("#trial_synonym_search_dialog_starting").hide();
    jQuery("#trial_synonym_search_dialog_working").hide();
    jQuery("#trial_synonym_search_dialog_results").show();
    jQuery("#trial_synonym_search_dialog_continue").attr("disabled", false);
}


function trial_toggle_match_type() {
    let type = jQuery(this).data('match-type');
    jQuery("#trial_synonym_search_dialog_results_none").hide();
    if ( type === 'all' ) {
        jQuery(".match-row").show();
    }
    else {
        jQuery(".match-row").hide();
        jQuery(".match-row-" + type).show();
    }
}


function trial_complete_synonym_search() {
    let selections = jQuery('.synonym_search_radio:checked');
    
    // Pull out replacements, existing, and new entries
    let replacements = [];
    let create = [];
    let existing = [];
    
    // Parse the user's selections
    for ( let i = 0; i < selections.length; i++ ) {
        let selection = jQuery(selections[i]);
        let user_name = selection.attr('name');
        let db_name = selection.attr('value');
        let db_id = selection.data("stock-id");
        if ( !db_name || db_name === '' ) {
            create.push(user_name);
        }
        else if ( db_name === user_name ) {
            existing.push(user_name);
        }
        else if ( db_name !== user_name ) {
            replacements.push({
                user_name: user_name,
                db_name: db_name,
                db_id: db_id
            });
        }
    }

    // Sort the selections
    replacements.sort(function(a, b) { (a.user_name > b.user_name) ? 1 : -1 });
    create.sort();
    existing.sort();

    // Display Replacements
    let r_html = '';
    if ( replacements.length === 0 ) {
        r_html += "<p><em>No replacements selected</em></p>";
    }
    else {
        r_html += "<table class='table table-bordered table-hover'>";
        r_html += "<thead><tr><th>Your Accession Name</th><th>Replacement Database Accession Name</th></tr></thead>";
        r_html += "<tbody>";
        for ( let i = 0; i < replacements.length; i++ ) {
            let r = replacements[i];
            r_html += "<tr><td>" + r.user_name + "</td><td>" + r.db_name + "</td></tr>";
        }
        r_html += "</tbody>";
        r_html += "</table>";
    }
    jQuery("#trial_review_synonym_search_dialog_replacements").html(r_html);

    // Display New Entries
    let c_html = '';
    if ( create.length === 0 ) {
        jQuery('#trial_review_synonym_search_dialog_create_well').hide();
    }
    else {
        jQuery('#trial_review_synonym_search_dialog_create_well').show();
        c_html += "<p>" + create.join(', ') + "</p>";
    }
    jQuery("#trial_review_synonym_search_dialog_create").html(c_html);

    // Display Existing Entries
    let e_html = '';
    if ( existing.length === 0 ) {
        e_html += "<p><em>No existing Accession entries will be updated</em></p>";
    }
    else {
        e_html += "<p>" + existing.join(', ') + "</p>";
    }
    jQuery("#trial_review_synonym_search_dialog_existing").html(e_html);

    jQuery('#trial_review_synonym_search_dialog').modal('show');
    
    jQuery('#trial_review_synonym_search_dialog_back').off('click').on('click', function() {
        jQuery("#trial_synonym_search_dialog").modal('show');
    });
    jQuery('#trial_review_synonym_search_dialog_continue').off('click').on('click', function() {
        trial_store_synonym_search(replacements)
    });
}


function trial_store_synonym_search(replacements) {
    console.log(replacements);
    let init_synonym_search_check = jQuery("#multi_trial_synonym_search_check").prop("checked");
    jQuery("#multi_trial_synonym_search_check").prop("checked", false);
    jQuery("#multi_trial_synonym_search_replacements").val(encodeURIComponent(JSON.stringify(replacements)));
    jQuery("#upload_multiple_trial_designs_form").submit();
    jQuery("#multi_trial_synonym_search_check").prop("checked", init_synonym_search_check);
}