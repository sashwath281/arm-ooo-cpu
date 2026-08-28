`timescale 1ps/1ps

// Generates a brand new .arm file every single run with a random number of instructions. 
// Written to disk using $fopen/$fwrite/$fclose.
class random_sequence extends uvm_sequence #(commit_item);

    `uvm_object_utils(random_sequence)

    rand int num_instructions;

    constraint c_length {
        num_instructions inside {[10:50]};
    }

    function new(string name = "random_sequence");
        super.new(name);
    endfunction


    task body();
        random_inst_item inst;  // Create a random instruction from the random_inst_item
        int fd;
        
        assert(this.randomize());   // Starts randomization of num_instructions. 
        
        fd = $fopen("sw/tests/random_generated.arm", "w");      // opens a new file at location for Writing. 
                                                                // Returns the file descriptor as fd, which we use later down. 
        
        repeat(num_instructions) begin                          // Run the randomly generated num of times
            inst = random_inst_item::type_id::create("inst");   // Instantiate the instruction through UVM Factory 
            assert(inst.randomize());                           // Starts randomization of the instruction (type, reg values, and immediates)
            inst.encode();                                      // Convert the random fields into the actual 32-bit instruction. 
            
            $fwrite(fd, "%032b\n", inst.instruction);           // Write the instruction to the file we created. 
                                                                // Its formatted as 32-bit binary padded with leadin 0s to always be 32 bits wide
        end
        
        $fwrite(fd, "%032b\n", 32'b0);                          // End pf program marker
        $fclose(fd);                                            // close the file and release file handle
        
        `uvm_info("RAND", $sformatf("Generated %0d random instructions", num_instructions), UVM_LOW)    // A low print statement 
    endtask

endclass