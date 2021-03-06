#include "cuda.h"

#include "alphabeta.h"
#include "node.h"
#include <cstdint>
#include <iostream>
#include <map>
#include <vector>
#include <chrono>

int DEPTH = 2;

unsigned int get_bots_move(node const&);
void init_node(node *);

unsigned int launchKernel(node const& current_node){
    const int n_threads = N_CHILDREN;


 /*   node *dev_nodes;
    float* dev_values;

    cudaMalloc((void**) &dev_values, sizeof(float) * n_threads); //after we incorporate scan, this array should be moved to shared memeory
    cudaMalloc((void**) &dev_nodes, sizeof(node) * n_threads); //unused. According to Sewcio should be * n_blocks not n_children
    cudaMemcpy(dev_nodes, nodes, sizeof(node) * n_threads, cudaMemcpyHostToDevice);
   */
    dim3 numThreads(n_threads, 1/*n_children*/, 1);

    unsigned int best_move;
 //   alpha_beta(dev_nodes, dev_values, current_node, DEPTH, &best_move, numThreads); //TODO: for now it's cudaDeviceSynchronize();
    alpha_beta(current_node, DEPTH, &best_move, numThreads);
    
    /*delete[] nodes;
    cudaFree((void**) &dev_values);
    cudaFree((void**) &dev_nodes); //TODO: so far I decided that it indeed should be n_threads, not n_blocks. We'll see later.
    */
    return best_move;
}


typedef unsigned int (*strategy)(node const&);
typedef std::chrono::duration<double> time_interv;


unsigned int count_time(strategy player, node const& n, time_interv *player_time)
{
    std::chrono::time_point<std::chrono::system_clock> start, end;
    start = std::chrono::system_clock::now();
    
    unsigned int move = player(n);

    end = std::chrono::system_clock::now();
    *player_time += end-start;
    
    return move;
    //std::time_t end_time = std::chrono::system_clock::to_time_t(end);
}

int main(int argc, char *argv[]){
    std::map<std::string, strategy> players = {
        {"stdin", get_console_move},
        {"cpu", get_alpha_beta_cpu_move},
        {"gpu", get_alpha_beta_gpu_move},
        {"gpukk", launchKernel}
    };
    if(argc < 3 || !players.count(argv[1]) || !players.count(argv[2])){
        std::cout << "Usage: " << argv[0] << " player1 player2 [full_display = 1 [depth = 4 [cut_after = 0 ]]]" << std::endl;
        std::cout << "\twhere\n- player1, player 2 is one of:";
        for(auto p : players)
            std::cout << " " << p.first;
        std::cout << "\n- full_display set to 0 means printing only the time used by the players";
        std::cout << "\n- depth >= 2, means the real depth (edge-wise), so default 4 is what Sewcio-compatible APIs call \"depth == 2\"";
        std::cout << "\n- cut_after set to i means only returning the time spend on the first i moves by each player, 0 - full game.";
        std::cout << std::endl;
        return 0;
    }

  
    bool full_display = 1;
    int cut_after = 0;
    if(argc >= 4)
    {
        full_display = std::stoi(argv[3]);
        if(argc >= 5)
        {
            DEPTH = std::stoi(argv[4]) - 2;
            std::cout << DEPTH << std::endl;
            if(argc >= 6)
            {
                cut_after = std::stoi(argv[5]);
            }
        }
    }
    if(cut_after == 0)
      cut_after = 100000000;
    else if(cut_after == -1)
        cut_after = 1200000;

    auto player1 = players[argv[1]];
    auto player2 = players[argv[2]];
    node nodes[2];
    init_node(nodes);
    int i;
    
    time_interv pl1_time(0), pl2_time(0);
    int move_counter = 0;

    for(i = 0; !is_terminal(nodes[i]); i=1-i){
        unsigned int move;
	    if(full_display)
	      std::cout << nodes[i] << "Node value: " << value(nodes[i]) << std::endl;
	    if(i==0)
        {
            move = count_time(player1, nodes[i], &pl1_time);
            move_counter++;
        }
	    else
	    {
	        move = count_time(player2, nodes[i], &pl2_time);
	        if(move_counter >= cut_after)
	          break;
            if(cut_after == 1200000)
            {
                std::cout << "After " << move_counter << ":\nPlayer 1 (" << argv[1] << ") took " << pl1_time.count() << " total, average " << pl1_time.count()/move_counter << "s\n";
                std::cout << "Player 2 (" << argv[2] << ") took " << pl2_time.count() << " total, average " << pl2_time.count()/move_counter << "s\n";
            }
        }
        if(!get_child(nodes[i], move, nodes+1-i))
        {
            printf("move wrong %d\n", move);
            throw "Wrong move returned";
        }
    }
    if(move_counter >= cut_after)
      std::cout << "Reached the cut_after barrier\n";
    else
      std::cout << "GAME OVER. Player " << (i==1 ? "1 (O)" : "2 (X)") << " won!" << std::endl;
    if(full_display)
       std::cout << nodes[i];
    std::cout << "Player 1 (" << argv[1] << ") took " << pl1_time.count() << " total, average " << pl1_time.count()/move_counter << "s\n";
    std::cout << "Player 2 (" << argv[2] << ") took " << pl2_time.count() << " total, average " << pl2_time.count()/(move_counter-i) << "s\n";
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
