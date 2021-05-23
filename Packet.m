classdef Packet
    properties
        id;  %ID of the sender node
        FI;  %Frame Information of the sender node
    end
    
    methods
        function self = Packet(node)
            self.id = node.id;
            self.FI = node.frameInfo;
        end
    end
end