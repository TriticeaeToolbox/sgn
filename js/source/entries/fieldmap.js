import '../legacy/d3/d3Min.js';
import '../legacy/jquery.js';
import '../legacy/brapi/BrAPI.js';


export function init() {
    class FieldMap {
        constructor(trial_id) {
            this.trial_id = String;
            this.plot_arr = Array;
            this.plot_object = Object;
            this.meta_data = {};
            this.brapi_plots = Object;
            this.heatmap_queried = false;
            this.heatmap_selected = false;
            this.heatmap_selection = String;
            this.heatmap_object = Object;
        }

        set_id(trial_id) {
            this.trial_id = trial_id;
        }

        format_brapi_post_object() {
            let brapi_post_plots = [];
            let count = 1;
            for (let plot of this.plot_arr.filter(plot => plot.type == "filler")) {
                brapi_post_plots.push({
                    "additionalInfo": {
                        "invert_row_checkmark": document.getElementById("invert_row_checkmark").checked,
                        "top_border_selection": this.meta_data.top_border_selection || false,
                        "left_border_selection": this.meta_data.left_border_selection || false,
                        "right_border_selection": this.meta_data.right_border_selection || false,
                        "bottom_border_selection": this.meta_data.bottom_border_selection || false,
                        "plot_layout": this.meta_data.plot_layout || "serpentine",
                        "type": "filler",
                    },
                    "germplasmDbId": this.meta_data.filler_accession_id,
                    "germplasmName": this.meta_data.filler_accession_name,
                    "observationUnitName": this.trial_id + " filler " + count,
                    "observationUnitPosition": {
                        "observationLevel": {
                            "levelCode": parseInt(this.meta_data.max_level_code) + count,
                            "levelName": "plot",
                            "levelOrder": 2
                        },
                        "positionCoordinateX": plot.observationUnitPosition.positionCoordinateX,
                        "positionCoordinateY": plot.observationUnitPosition.positionCoordinateY,
                    },
                    "trialDbId": this.trial_id,
                    "studyDbId": this.trial_id,
                });
                count++;
            }
            return brapi_post_plots;
        }

        format_brapi_put_object() {
            let brapi_plots = {};
            for (let plot of this.plot_arr.filter(plot => plot.type == "data")) {
                brapi_plots[plot.observationUnitDbId] = {
                    "additionalInfo": {
                        "invert_row_checkmark": document.getElementById("invert_row_checkmark").checked,
                        "top_border_selection": this.meta_data.top_border_selection || false,
                        "left_border_selection": this.meta_data.left_border_selection || false,
                        "right_border_selection": this.meta_data.right_border_selection || false,
                        "bottom_border_selection": this.meta_data.bottom_border_selection || false,
                        "plot_layout": this.meta_data.plot_layout || "serpentine",
                    },
                    "germplasmDbId": plot.germplasmDbId,
                    "germplasmName": plot.gerplasmName,
                    "observationUnitName": plot.observationUnitName,
                    "observationUnitPosition": {
                        "observationLevel": {
                            "levelCode": plot.observationUnitPosition.observationLevel.levelCode,
                            "levelName": "plot",
                            "levelOrder": 2
                        },
                        "positionCoordinateX": plot.observationUnitPosition.positionCoordinateX,
                        "positionCoordinateY": plot.observationUnitPosition.positionCoordinateY,
                    },
                    "trialDbId": this.trial_id,
                }
            }
            return brapi_plots;
        }

        filter_data(data) {
            var plants = [];
            var plant_obj = {};
            var plot_object = {};
            for (let plot of data) {
                var obs_level = plot.observationUnitPosition.observationLevel;
                if (obs_level.levelName == "plot") {
                    plot.observationUnitPosition.positionCoordinateX = parseInt(plot.observationUnitPosition.positionCoordinateX);
                    plot.observationUnitPosition.positionCoordinateY = parseInt(plot.observationUnitPosition.positionCoordinateY);
                    plot.type = "data";
                    plot_object[plot.observationUnitDbId] = plot;
                }   
            }
            this.plot_object = plot_object;
        }

        filter_heatmap(observations) {
            this.heatmap_object = {};
            for (let observation of observations) {
                let trait_name = observation.observationVariableName;
                if (!this.heatmap_object[trait_name]) {
                    this.heatmap_object[trait_name] = {[observation.observationUnitDbId]: {val: observation.value, plot_name: observation.observationUnitName, id: observation.observationDbId }};
                } else {
                    this.heatmap_object[trait_name][observation.observationUnitDbId] = {val: observation.value, plot_name: observation.observationUnitName, id: observation.observationDbId };
                }
            }
        }

        invert_rows() {
            if (this.meta_data.invert_row_checkmark) {
                for (let i = 0; i < this.plot_arr.length; i++) {
                    this.plot_arr[i].observationUnitPosition.positionCoordinateY = this.meta_data.max_row - this.plot_arr[i].observationUnitPosition.positionCoordinateY + 1;
                }
            }

        }

        traverse_map(planting_or_harvesting_order_layout) {
            var order_arr = [...Object.values(this.plot_object)];
            order_arr.sort(function(a,b) { return parseFloat(a.observationUnitPosition.observationLevel.levelCode) - parseFloat(b.observationUnitPosition.observationLevel.levelCode) });
            let final_arr = [];
            if (this.meta_data[planting_or_harvesting_order_layout].includes('row')) {
                final_arr = order_arr;
            } else {
                let temp_arr = [];
                for (let i = 0; i < this.meta_data.num_rows; i++) {
                    temp_arr.push([...order_arr.slice(i * this.meta_data.num_cols, (i * this.meta_data.num_cols + this.meta_data.num_cols))])
                    if (this.meta_data.plot_layout == "serpentine" && i % 2 == 1) {
                        temp_arr[i].reverse();
                    }
                }

                if (planting_or_harvesting_order_layout == "planting_order_layout") {
                    return temp_arr;
                }

                for (let i = 0; i < this.meta_data.num_cols; i++) {
                    let row_coord;
                    for (let j = 0; j < this.meta_data.num_rows; j++) {
                        if (this.meta_data[planting_or_harvesting_order_layout] == "by_col_serpentine" && i % 2 == 1) {
                            row_coord = this.meta_data.num_rows - j - 1;
                        } else {
                            row_coord = j;
                        }
                        final_arr.push(temp_arr[row_coord][i]);
                    }
                }
            }
            return final_arr;
        }

        get_harvesting_order() {
            var final_harvesting_arr = this.traverse_map('planting_order_layout');
            var csv = ['PlotNumber', 'PlotName', 'AccessionName',].join(',');
            csv += "\n";
            final_harvesting_arr.forEach(function(plot) {
                    csv += [plot.observationUnitPosition.observationLevel.levelCode, plot.observationUnitName, plot.germplasmName].join(',');
                    csv += "\n";
            });
    
            var hiddenElement = document.createElement('a');
            hiddenElement.href = 'data:text/csv;charset=utf-8,' + encodeURI(csv);
            hiddenElement.target = '_blank';
            
            hiddenElement.download = `Trial_${this.trial_id}_${this.meta_data.harvesting_order_layout}_HarvestingOrder.csv`;
            hiddenElement.click();    
        }

        get_planting_order() {
            var planting_arr = this.traverse_map('planting_order_layout');
            let num_rows = this.meta_data.top_border_selection ? this.meta_data.num_rows + 1 : this.meta_data.num_rows;
            num_rows = this.meta_data.bottom_border_selection ? num_rows + 1 : num_rows;
            let num_cols = this.meta_data.left_border_selection ? this.meta_data.num_cols + 1 : this.meta_data.num_cols;
            num_cols = this.meta_data.right_border_selection ? num_cols + 1 : num_cols;
            const border_plot = {
                observationUnitName: "Border Plot",
                germplasmName: "N/A",
                observationUnitPosition: {
                    observationLevel: {
                        levelCode: "N/A"
                    }
                }
            }
            if (this.meta_data.planting_order_layout == "by_row") {
                let temp_arr = [];
                    for (let i = 0; i < this.meta_data.num_rows; i++) {
                        temp_arr.push([...planting_arr.slice(i * this.meta_data.num_cols, (i * this.meta_data.num_cols + this.meta_data.num_cols))]);
                    }
                planting_arr = temp_arr;
            }
            if (this.meta_data.left_border_selection || this.meta_data.right_border_selection) {
                for (let arr of planting_arr) {
                    if (this.meta_data.left_border_selection) {
                        arr.unshift(border_plot);
                    }
                    if (this.meta_data.right_border_selection) {
                        arr.push(border_plot);
                    }
                }   
            }
            if ((this.meta_data.invert_row_checkmark && this.meta_data.top_border_selection) || (!this.meta_data.invert_row_checkmark && this.meta_data.bottom_border_selection)) {
                planting_arr = [ [...Array(num_cols).fill(border_plot, 0, num_cols)], ...planting_arr]
            }
            if ((this.meta_data.invert_row_checkmark && this.meta_data.bottom_border_selection) || (!this.meta_data.invert_row_checkmark && this.meta_data.top_border_selection)) {
                planting_arr = [...planting_arr, [...Array(num_cols).fill(border_plot, 0, num_cols)]]
            }

            let final_arr = [];
            if (this.meta_data.planting_order_layout != "by_row") {
                for (let i = 0; i < num_cols; i++) {
                    let row_coord;
                    for (let j = 0; j < num_rows; j++) {
                        if (this.meta_data.planting_order_layout == "by_col_serpentine" && i % 2 == 1) {
                            row_coord = num_rows - j - 1;
                        } else {
                            row_coord = j;
                        }
                        final_arr.push(planting_arr[row_coord][i]);
                    }
                }
            } else {
                for (let arr of planting_arr) {
                    for (let elem of arr) {
                        final_arr.push(elem);
                    }
                }
            }
            var csv = ['PlotNumber', 'PlotName', 'AccessionName',].join(',');
            csv += "\n";
            final_arr.forEach(function(plot) {
                    csv += [plot.observationUnitPosition.observationLevel.levelCode, plot.observationUnitName, plot.germplasmName].join(',');
                    csv += "\n";
            });
            
            var hiddenElement = document.createElement('a');
            hiddenElement.href = 'data:text/csv;charset=utf-8,' + encodeURI(csv);
            hiddenElement.target = '_blank';
            
            hiddenElement.download = `Trial_${this.trial_id}_${this.meta_data.harvesting_order_layout}_PlantingOrder.csv`;
            hiddenElement.click();    
        }

        set_meta_data() {
            // this.plot_arr = JSON.parse(JSON.stringify(Object.values(this.plot_object)));
            this.plot_arr = Object.values(this.plot_object);
            this.plot_arr.sort(function(a,b) { return parseFloat(a.observationUnitPosition.observationLevel.levelCode) - parseFloat(b.observationUnitPosition.observationLevel.levelCode) });
            var min_col = 100000;
            var min_row = 100000;
            var max_col = 0;
            var max_row = 0;
            var max_level_code = 0;
            for (let plot of this.plot_arr) {
                max_col = plot.observationUnitPosition.positionCoordinateX > max_col ? plot.observationUnitPosition.positionCoordinateX : max_col;
                min_col = plot.observationUnitPosition.positionCoordinateX < min_col ? plot.observationUnitPosition.positionCoordinateX : min_col;
                max_row = plot.observationUnitPosition.positionCoordinateY > max_row ? plot.observationUnitPosition.positionCoordinateY : max_row;
                min_row = plot.observationUnitPosition.positionCoordinateY < min_row ? plot.observationUnitPosition.positionCoordinateY : min_row;
                max_level_code = parseInt(plot.observationUnitPosition.observationLevel.levelCode) > max_level_code ? plot.observationUnitPosition.observationLevel.levelCode : max_level_code;
            }
            this.meta_data.min_row = min_row;
            this.meta_data.max_row = max_row;
            this.meta_data.min_col = min_col;
            this.meta_data.max_col = max_col;
            this.meta_data.num_rows = max_row - min_row + 1;
            this.meta_data.num_cols = max_col - min_col + 1;
            this.meta_data.max_level_code = max_level_code;
        }

        check_element(selection, element_id) {
            document.getElementById(element_id).checked = selection;
        }

        check_elements(additionalInfo) {
            var elements = ["top_border_selection", "left_border_selection", "right_border_selection", "bottom_border_selection", "invert_row_checkmark"];
            for (let element of elements) {
                this.check_element(additionalInfo[element], element);
                this.meta_data[element] = additionalInfo[element];
            }
        }

        get_plot_format(type, x, y) {
            return { 
                type: type, observationUnitPosition: { positionCoordinateX: x, positionCoordinateY: y, } 
            }
        }

        change_dimensions(cols, rows) {
            var cols = parseInt(cols);
            var rows = parseInt(rows);
            this.meta_data.post = false;
            this.meta_data.num_cols = cols;
            this.meta_data.num_rows = rows;
            this.plot_arr = [
                ...this.plot_arr.slice(0, Object.entries(this.plot_object).length),
            ];
            var count = 0;
            var column;

            if (!this.meta_data.plot_layout) {
                this.meta_data.plot_layout = "serpentine";
            }
            for (let j = 0; j < (rows); j++) {
                for (let i = 0; i < (cols); i++) {
                    column = this.meta_data.plot_layout == "serpentine" && j % 2 == 1 ? this.meta_data.max_col - i : this.meta_data.min_col + i;
                    if (!this.plot_arr[count]) {
                        this.meta_data.post = true;
                        this.plot_arr[count] = this.get_plot_format('filler', column, this.meta_data.max_row - j, );
                    } else if (this.plot_arr[count].observationUnitPosition) {
                        this.plot_arr[count].observationUnitPosition.positionCoordinateX = column;
                        this.plot_arr[count].observationUnitPosition.positionCoordinateY = this.meta_data.max_row - j;
                    }
                        count += 1;
                }
            }
            this.meta_data.max_row = rows + this.meta_data.min_row - 1;
            this.meta_data.max_col = cols + this.meta_data.min_col - 1;


        }
        add_corners() {
            var add_corner = (condition_1, condition_2, x,y) => {
                if (condition_1 && condition_2) {
                    this.plot_arr.push(this.get_plot_format("border", x, y));
                }
            }
            add_corner(this.meta_data.top_border_selection, this.meta_data.left_border_selection, this.meta_data.min_col - 1, this.meta_data.min_row - 1);
            add_corner(this.meta_data.top_border_selection, this.meta_data.right_border_selection, this.meta_data.max_col + 1, this.meta_data.min_row - 1);
            add_corner(this.meta_data.bottom_border_selection, this.meta_data.left_border_selection, this.meta_data.min_col - 1, this.meta_data.max_row + 1);
            add_corner(this.meta_data.bottom_border_selection, this.meta_data.right_border_selection, this.meta_data.max_col + 1, this.meta_data.max_row + 1);

        }
        add_border(border_element, row_or_col, min_or_max) {
            var start_iter;
            var end_iter;
            if (row_or_col == "row") {
                start_iter = this.meta_data.min_col;
                end_iter = this.meta_data.max_col;
            } else if (row_or_col == "col") {
                start_iter = this.meta_data.min_row;
                end_iter = this.meta_data.max_row;
            }

            if (this.meta_data[border_element]) {
                for (let i = start_iter; i <= end_iter; i++) {
                    this.plot_arr.push(this.get_plot_format("border", row_or_col == "row" ? i : min_or_max, row_or_col == "row" ? min_or_max : i));
                }
            }
        }

        add_borders() {
            this.add_border("left_border_selection", "col", this.meta_data.min_col - 1);
            this.add_border("top_border_selection", "row", this.meta_data.min_row - 1);
            this.add_border("right_border_selection", "col", this.meta_data.max_col + 1);
            this.add_border("bottom_border_selection", "row", this.meta_data.max_row + 1);
            this.add_corners();
        }

        clickcancel() {
            var event = d3.dispatch('click', 'dblclick');
            function cc(selection) {
                var down,
                    tolerance = 5,
                    last,
                    wait = null;
                function dist(a, b) {
                    return Math.sqrt(Math.pow(a[0] - b[0], 2), Math.pow(a[1] - b[1], 2));
                }
                selection.on('mousedown', function() {
                    down = d3.mouse(document.body);
                    last = +new Date();
                });
                selection.on('mouseup', function() {
                    if (dist(down, d3.mouse(document.body)) > tolerance) {
                        return;
                    } else {
                        if (wait) {
                            window.clearTimeout(wait);
                            wait = null;
                            event.dblclick(d3.event);
                        } else {
                            wait = window.setTimeout((function(e) {
                                return function() {
                                    event.click(e);
                                    wait = null;
                                };
                            })(d3.event), 300);
                        }
                    }
                });
            };
            return d3.rebind(cc, event, 'on');
        }

        heatmap_plot_click(plot, heatmap_object, trait_name) {
            if (d3.event && d3.event.detail > 1) {
                return;
            } else if (trait_name in heatmap_object && heatmap_object[trait_name][plot.observationUnitDbId]) {
                let val, plot_name, pheno_id;
                val = heatmap_object[trait_name][plot.observationUnitDbId].val;
                plot_name = heatmap_object[trait_name][plot.observationUnitDbId].plot_name; 
                pheno_id = heatmap_object[trait_name][plot.observationUnitDbId].id;
                jQuery("#suppress_plot_pheno_dialog").modal("show"); 
                jQuery("#myplot_name").html(plot_name);
                jQuery("#pheno_value").html(val);
                jQuery("#mytrait_id").html(trait_name);
                jQuery("#mypheno_id").html(pheno_id);
            }
        }

        fieldmap_plot_click(plot) {
            if (d3.event && d3.event.detail > 1) {
                return;
            } else {
                function btnClick(n){
                    if (n.length == 0){
                        jQuery("#hm_view_plot_image_submit").addClass("disabled");
                    } else {
                        jQuery("#hm_view_plot_image_submit").removeClass("disabled");
                    }
                    return true; 
                }
                if (plot.type == "data") {
                    var image_ids = plot.plotImageDbIds || [];
                    var replace_accession = plot.germplasmName;
                    var replace_plot_id = plot.observationUnitDbId;
                    var replace_plot_name = plot.observationUnitName;plot
                    var replace_plot_number = plot.observationUnitPosition.observationLevel.levelCode;

                    jQuery('#plot_image_ids').html(image_ids);
                    jQuery('#hm_replace_accessions_link').find('button').trigger('click');
                    jQuery("#hm_replace_accessions_link").on("click", function(){ btnClick(image_ids); });
                    jQuery('#hm_edit_plot_information').html('<b>Selected Plot Information: </b>');
                    jQuery('#hm_edit_plot_name').html(replace_plot_name);
                    jQuery('#hm_edit_plot_number').html(replace_plot_number);
                    var old_plot_id = jQuery('#hm_edit_plot_id').html(replace_plot_id);
                    var old_plot_accession = jQuery('#hm_edit_plot_accession').html(replace_accession);
                    jQuery('#hm_replace_plot_accessions_dialog').modal('show');

                    new jQuery.ajax({
                        type: 'POST',
                        url: '/ajax/breeders/trial/'+ trial_id +'/retrieve_plot_images',
                        dataType: "json",
                        data: {
                                'image_ids': JSON.stringify(image_ids),
                                'plot_name': replace_plot_name,
                                'plot_id': replace_plot_id,
                        },
                        success: function (response) {
                        jQuery('#working_modal').modal("hide");
                        var images = response.image_html;
                        if (response.error) {
                            alert("Error Retrieving Plot Images: "+response.error);
                        }
                        else {
                            jQuery("#show_plot_image_ids").html(images);

                        // jQuery('#view_plot_image_dialog').modal("show"); 
                        }
                        },
                        error: function () {
                            jQuery('#working_modal').modal("hide");
                            alert('An error occurred retrieving plot images');
                        }
                    });
                }
            }
        }
        
        FieldMap() {
            var cc = this.clickcancel();
            const colors = ["#ffffd9","#edf8b1","#c7e9b4","#7fcdbb","#41b6c4","#1d91c0","#225ea8","#253494","#081d58"];
            var trait_name = this.heatmap_selection;
            var heatmap_object = this.heatmap_object;
            var plot_click = !this.heatmap_selected ? this.fieldmap_plot_click : this.heatmap_plot_click;
            var trait_vals = [];
            
            if (this.heatmap_selected) {
                let plots_with_selected_trait = heatmap_object[trait_name];
                for (let obs_unit of Object.values(plots_with_selected_trait)) {
                    trait_vals.push(obs_unit.val);
                }
                var colorScale = d3.scale.quantile()
                .domain(trait_vals)
                .range(colors);
            }

            var get_fieldmap_plot_color = function(plot) {
                var color;
                if (plot.observationUnitPosition.observationLevelRelationships) {
                    if (plot.observationUnitPosition.entryType == "check") {
                        color = "#6a5acd";
                    } else if (plot.observationUnitPosition.observationLevelRelationships[1].levelCode % 2 == 0) {
                        color = "#c7e9b4";
                    } else if (plot.additionalInfo && plot.additionalInfo.type == "filler") {
                        color = "lightgrey";    
                    } else {
                        color = "#41b6c4";
                    }
                } else {
                    color = "lightgrey";
                }
                return color;
            }
            
            var get_heatmap_plot_color = function(plot) {
                var color;
                if (!plot.observationUnitPosition.observationLevel) {
                    color = "lightgrey";
                } else {
                    color = heatmap_object[trait_name][plot.observationUnitDbId] ? colorScale(heatmap_object[trait_name][plot.observationUnitDbId].val) : "white";
                }
                return color;
            }
            var get_stroke_color = function(plot) {
                var stroke_color;
                if (plot.observationUnitPosition.observationLevel) {
                    if (plot.observationUnitPosition.observationLevelRelationships[0].levelCode % 2 == 0) {
                        stroke_color = "red"
                    } else {
                        stroke_color = "green";
                    }
                } else {
                    stroke_color = "black";
                }
                return stroke_color;
            }

            var get_plot_message = function(plot) {
                if (plot.type != "data") {
                    return "Plot Name: " + plot.observationUnitName;
                } else {
                    return ` 
                        Plot Name: ${plot.observationUnitName}
                        Plot Number: ${plot.observationUnitPosition.observationLevel.levelCode}
                        Block Number: ${plot.observationUnitPosition.observationLevelRelationships[1].levelCode}
                        Rep Number: ${plot.observationUnitPosition.observationLevelRelationships[2].levelCode}
                        Accession Name: ${plot.germplasmName}
                    `
                }
            }
            var width = this.meta_data.left_border_selection ? this.meta_data.max_col + 3 : this.meta_data.max_col + 2;
            width = this.meta_data.right_border_selection ? width + 1 : width;
            var height = this.meta_data.top_border_selection ? this.meta_data.max_row + 3 : this.meta_data.max_row + 2;
            height = this.meta_data.bottom_border_selection ? height + 1 : height;
            var row_increment = this.meta_data.invert_row_checkmark ? 1 : 0;
            row_increment = this.meta_data.top_border_selection ? row_increment : row_increment - 1;
            var grid = d3.select("#container_fm")
            .append("svg")
            .attr("width", width * 50 + 20 + "px")
            .attr("height", height * 50 + 20 + "px");

            var tooltip = d3.select("#container_fm")
            .append('div')
            .attr('id', 'tooltip')
            .attr('class', 'tooltip')
            .attr('style', 'position: absolute; opacity: 0;');
            
            var isHeatMap = this.heatmap_selected;
            var plots = grid.selectAll("plots")
            .data(this.plot_arr);
            plots.append("title");
            plots.enter().append("rect")
                .attr("x", function(d) { return (d.observationUnitPosition.positionCoordinateX + 1) * 50 + 15; })
                .attr("y", function(d) { return (d.observationUnitPosition.positionCoordinateY + row_increment) * 50 + 15; })
                .attr("rx", 4)
                .attr("class", "col bordered")
                .attr("width", 50)
                .attr("height", 50)
                .style("stroke-width", 2)
                .style("stroke", function(d) { return get_stroke_color(d)})
                .style("fill", function(d) {return !isHeatMap ? get_fieldmap_plot_color(d) : get_heatmap_plot_color(d)})
                .on("mouseover", function(d) { if (d.observationUnitPosition.observationLevel) { 
                    d3.select(this).style('fill', 'green').style('cursor', 'pointer'); 
                    d3.select('#tooltip')
                    .style('opacity', .9)
                    .style('left', ((d.observationUnitPosition.positionCoordinateX + 1) * 50 + 100) + 'px')
                    .style('top', ((d.observationUnitPosition.positionCoordinateY + row_increment) * 50 + 540) + 'px')
                    .text(get_plot_message(d))
                }})
                .on("mouseout", function(d) { 
                    d3.select(this).style('fill', !isHeatMap ? get_fieldmap_plot_color(d) : get_heatmap_plot_color(d)).style('cursor', 'default')
                    d3.select('#tooltip').style('opacity', 0)
                    plots.exit().remove();
                }).call(cc);

            cc.on("click", function(el) { var plot = d3.select(el.srcElement).data()[0]; plot_click(plot, heatmap_object, trait_name) });
            cc.on("dblclick", function(el) { var me = d3.select(el.srcElement);
                var d = me.data()[0];
                if (d.observationUnitDbId) {
                    window.open('/stock/'+d.observationUnitDbId+'/view');        
                }
            });

            plots.append("text");
                    plots.enter().append("text")
                    .attr("x", function(d) { return (d.observationUnitPosition.positionCoordinateX + 1) * 50 + 25; })
                    .attr("y", function(d) { return (d.observationUnitPosition.positionCoordinateY + row_increment) * 50 + 45; })
                    .text(function(d) { if ((d.type == "data" && !d.additionalInfo) || (d.type == "data" && d.additionalInfo.type != "filler")) { return d.observationUnitPosition.observationLevel.levelCode; }});

            var image_icon = function (d){
                var image = d.plotImageDbIds || []; 
                var plot_image;
                if (image.length > 0){
                    plot_image = "/static/css/images/plot_images.png"; 
                }else{
                    plot_image = "";
                }
                return plot_image;
            }

            plots.enter().append("image")
            .attr("xlink:href", image_icon)
            .attr("x", function(d) { return (d.observationUnitPosition.positionCoordinateX + 1) * 50 + 42; })
            .attr("y", function(d) { return (d.observationUnitPosition.positionCoordinateY + row_increment) * 50 + 15; })
            .attr("width", 20)
            .attr("height", 20);
                                      
            plots.exit().remove();

            var row_label_arr = [];
            var col_label_arr = [];
            for (let i = 1; i <= this.meta_data.num_rows; i++) {
                row_label_arr.push(i);
            }
            for (let i = 1; i <= this.meta_data.num_cols; i++) {
                col_label_arr.push(i);
            }
            var col_labels_row = this.meta_data.min_row - 1;
            if (!this.meta_data.invert_row_checkmark) {
                col_labels_row = this.meta_data.bottom_border_selection ? this.meta_data.max_row + 2 : this.meta_data.max_row + 1;
                col_labels_row = this.meta_data.top_border_selection ? col_labels_row : col_labels_row - 1;
                row_label_arr.reverse();
            }
            

            var rowLabels = grid.selectAll(".rowLabels") 
            .data(row_label_arr)
            .enter().append("text")
            .attr("x", ((this.meta_data.left_border_selection ? this.meta_data.min_col - 1 : this.meta_data.min_col) * 50) + 35)
            .attr("y", function(label) {return (label+row_increment) * 50 + 45})
            .text(function(label, i) {return i+1});

            var colLabels = grid.selectAll(".colLabels") 
            .data(col_label_arr)
            .enter().append("text")
            .attr("x", function(label) {return (label+1) * 50 + 30})
            .attr("y", (col_labels_row * 50) + 45)
            .text(function(label) {return label});
        }


        load() {
            d3.select("svg").remove();
            this.change_dimensions(this.meta_data.num_cols, this.meta_data.num_rows);
            this.change_dimensions(this.meta_data.num_cols, this.meta_data.num_rows);
            this.invert_rows();
            this.add_borders();
            this.render();
        }

        render() {
            jQuery("#working_modal").modal("hide");
            // jQuery("#chart_fm").css({ "display": "inline-block" });
            jQuery("#container_fm").css({ "display": "inline-block", "overflow": "auto" });
            jQuery("#trait_heatmap").css("display", "none");
            jQuery("#container_heatmap").css("display", "none");
            jQuery("#trait_heatmap").css("display", "none");
            this.FieldMap();

        }
    }

    const mapObj = new FieldMap();
    return mapObj;
}