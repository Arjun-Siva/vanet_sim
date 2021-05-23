clear;
import Packet;
import Node;

xmin= 0;
xmax= 2000;
n = 120;
x_s = round(xmin+rand(1,n)*(xmax-xmin));
x_s = sort(x_s);
y_s = [5;10;15;20];
nodes(n,1) = Node();

for i = 1:n
    nodes(i).id = i;
    nodes(i).x = x_s(i);
    nodes(i).y = y_s(randi([1 4]));
    nodes(i).packetToSend = Packet(nodes(i));
    nodes(i).range = 300;
    nodes(i).acquiredSlot = randi([1 60]);
    nodes(i).frameInfo(nodes(i).acquiredSlot) = i;
end

current_slot = 1;
round = 1;
numberOfTransmissions = zeros(n,1);
dataPackAt = 1;
nodes = arrayfun( @(x) x.findRelayId(nodes), nodes);

while dataPackAt ~= n
    for i = 1:n
        nodes = nodes(i).acquireSlot(current_slot,nodes);
    end
    
    for i = 1:n
        nodes = nodes(i).sendPackets(nodes,current_slot);
    end
    nodes = arrayfun( @(x) x.processPacket(current_slot), nodes);
    %nodes = arrayfun( @(x) x.incrementx(), nodes);
    datapack = [];
    for i = 1:numel(dataPackAt)
        if dataPackAt(i) ~= 0
            [datapackIds, nodes] = nodes(dataPackAt(i)).sendData(nodes,current_slot,"ocamac");
        end
        for j = 1:numel(datapackIds)
            if datapackIds(j) ~= 0
                datapack = [datapack;datapackIds];
            end
        end
    end
    uniq = unique(datapack);
    %disp("uniq:");disp(uniq);
    dataPackAt = uniq(end);
    numberOfTransmissions(dataPackAt) = numberOfTransmissions(dataPackAt) + 1;
    try
        dataPackAt = [dataPackAt;uniq(numel(uniq)-1)];
        numberOfTransmissions(dataPackAt(2)) = numberOfTransmissions(dataPackAt(2)) + 1;
    catch
    end
          
    
    
    %disp(dataPackAt);
    if current_slot == 60
        current_slot = 1;
        disp("Frame "+round+" over");
        round = round + 1;
        disp("Datapack at:"+ dataPackAt);
        plot([nodes.x]',[nodes.y]',"r>");hold on;
        plot([nodes(dataPackAt(1)).x; nodes(nodes(dataPackAt(1)).relayId).x], [nodes(dataPackAt(1)).y; nodes(nodes(dataPackAt(1)).relayId).y], "->b", "MarkerFaceColor","b");
        try
            plot([nodes(dataPackAt(2)).x; nodes(nodes(dataPackAt(2)).relayId).x], [nodes(dataPackAt(2)).y; nodes(nodes(dataPackAt(2)).relayId).y], "->b", "MarkerFaceColor","b");
        catch
        end
        hold off;
        pause(0.001);
    else
        current_slot = current_slot + 1;
    end
end
