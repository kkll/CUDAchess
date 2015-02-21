#include "cuda.h"

#include "alphabeta.h"
#include "node.h"
#include <cstdint>
#include <iostream>
#include <vector>

const int DEPTH = 5;

unsigned int get_bots_move(node const&);
unsigned int get_alpha_beta_gpu_move(node const&);

unsigned int launchKernel(node const& current_node){
    const int n_threads = N_CHILDREN;

    node* nodes = new node[n_threads];
    for(int i = 0; i < n_threads; i++){
	    nodes[i] = {};
    }

    node *dev_nodes;
    float* dev_values;

    cudaMalloc((void**) &dev_values, sizeof(float) * n_threads); //after we incorporate scan, this array should be moved to shared memeory
    cudaMalloc((void**) &dev_nodes, sizeof(node) * n_threads); //unused. According to Sewcio should be * n_blocks not n_children
    cudaMemcpy(dev_nodes, nodes, sizeof(node) * n_threads, cudaMemcpyHostToDevice);
    dim3 numThreads(n_threads, 1/*n_children*/, 1);

    unsigned int best_move;
    alpha_beta(dev_nodes, dev_values, current_node, DEPTH, &best_move, numThreads); //TODO: for now it's cudaDeviceSynchronize();
    
    delete[] nodes;
    cudaFree((void**) &dev_values);
    cudaFree((void**) &dev_nodes); //TODO: so far I decided that it indeed should be n_threads, not n_blocks. We'll see later.
    
    return best_move;
}

int main(){
    node nodes[2];
    nodes[0] = {};
    int i;
    for(i = 0; !is_terminal(nodes[i]); i=1-i){
        unsigned int move;
	    if(i==0)
	        move = get_console_move(nodes[i]);
	    else
	        move = get_alpha_beta_gpu_move(nodes[i]);
	    if(!get_child(nodes[i], move, nodes+1-i))
        {
            printf("move wrong %d\n", move);
            throw "Wrong move returned";
        }
    }
    std::cout << "GAME OVER" << std::endl << nodes[i];
    return 0;
}



unsigned int get_bots_move(node const &n)
{
    return launchKernel(n);
    /*for(unsigned int i = 0; i < n_children; i++)
        if(get_child(n, i, nullptr))
            return i;
    throw "no move can be done";
*/
}
