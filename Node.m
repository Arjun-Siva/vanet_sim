classdef Node
    properties
        % Properties of vehicles
        id;
        x;
        y;
        range;
        acquiredSlot=0;
        waitingTillSlot=0;
        frameInfo=zeros(60,1);
        packetQueue=[];
        packetToSend;
        onehopset=zeros(60,1);
        relayId;
        relayProb;
        cooperatingSlot=0;
        coopRelayId=0;
        relayPartnerId=0;
    end
    
    methods
  
        function self = incrementx(self)
            %Increase the x-coordinate of vehicle
            self.x = self.x + 10;
        end
        
        function nodes = acquireSlot(self,current_slot,nodes)
            % Acquire a free slot if the node doesn't have one
            if self.acquiredSlot == 0
                if self.waitingTillSlot == 0
                    nodes(self.id).waitingTillSlot = current_slot;
                elseif self.waitingTillSlot == current_slot
                    % Acquire a free slot from its frame information
                    zeroIdx = find(self.frameInfo==0);
                    try
                        self.acquiredSlot = zeroIdx(randi([1 numel(zeroIdx)]));
          
                        nodes(self.id).acquiredSlot = self.acquiredSlot;
                        nodes(self.id).frameInfo(self.acquiredSlot) = self.id;
                        ohs = self.onehopset;
                        for i = 1:60
                            if ohs(i)~=0
                                nodes(ohs(i)).onehopset(self.acquiredSlot) = self.id;
                                nodes(ohs(i)).frameInfo(self.acquiredSlot) = self.id;
                            end
                        end
                        
                        nodes(self.id).waitingTillSlot = 0;
                    catch
                        disp("No free slot found for: "+self.id);
                        disp(self.id + ":" + self.frameInfo);
                    end
                end
            end
        end
        
        function dist = distToNode(self,node)
            % Find the distance between two nodes
            dist = norm([self.x;self.y] - [node.x;node.y]);
        end
        
        function nodes = sendFrames(self,nodes,packet)
            % Send frames to all nodes in the node's OHS
            for i = 1:numel(nodes)
                if i == self.id
                    continue;
                end
                if self.distToNode(nodes(i)) <= self.range
                    nodes(i).packetQueue = [nodes(i).packetQueue; packet];
                end
            end
        end
        
        function self = processPacket(self,current_slot)
            % Process the received packet
            if self.acquiredSlot == current_slot
                self.packetQueue = [];
                return;
            end
            if numel(self.packetQueue) == 1
                % Only process if there are no collisions
                pack = self.packetQueue(1);
                if self.onehopset(current_slot) == pack.id
                    unalloc = find(self.frameInfo == 0);
                    for i = unalloc
                        try
                        if pack.FI(i) ~= 0
                            self.frameInfo(i) = pack.FI(i);
                        end
                        catch
                           % Invalid FI in packet
                        end
                    end
                    try
                        if pack.FI(self.acquiredSlot) == 0
                            %If the OHS packet doesn't have the node as
                            %it's neighbor, then the node loses it's
                            %acquired slot
                            self.acquiredSlot = 0;
                            
                        end
                    catch
                        %disp(self.id + "'s slot:" + self.acquiredSlot);
                    end
                else
                    %disp(self.id + " adding to its list:"+pack.id);
                    self.onehopset(current_slot) = pack.id;
                    self.frameInfo(current_slot) = pack.id;
                end
            else
                self.frameInfo(current_slot) = 0;
                self.onehopset(current_slot) = 0;
                %disp(self.id + " received no packs at "+current_slot);
            end
            self.packetQueue = [];
            self.packetToSend = self.resetPacket();
        end
        
        
        function nodes = sendPackets(self,nodes,current_slot)
            pack = self.packetToSend;
            if current_slot == self.acquiredSlot || current_slot == self.cooperatingSlot
                %disp(self.id+" sending");
                nodes = self.sendFrames(nodes,pack);
            end
        end
        
        function packet = resetPacket(self)
            %Reset the packet to send with latest frame information
            packet = self.packetToSend;
            packet.FI = self.frameInfo;
        end
        
        function prob = probOfSuccess(self,node)
            % Predict the probability of a successful data transmission
            % between two nodes
            d = self.distToNode(node);
            r = self.range;
            prob = 1 - ((d/r)^2);
        end
        
        function self = findRelayId(self, nodes)
            % Find the reliable farthest node to serve as multihop relay
            self.relayId = self.id; minprob = 1;
            for i = 1:numel(nodes)
                if i == self.id
                    continue;
                end
                
                if i > self.id
                    if self.distToNode(nodes(i)) < self.range
                        prob = self.probOfSuccess(nodes(i));
                        if prob < minprob
                            if prob > 0.14
                                self.relayId = i;
                                minprob = prob;
                            end
                        end
                    end
                end
            end
            self.relayProb = minprob;
            disp(self.id+"'s relay prob "+minprob+" to "+ self.relayId);
        end
        
        function coopNodeId = findRandomCoop(self,nodes)
            % Finding Cooperating node for CAHMAC
            ohs = self.onehopset;
            coopNodeId = 0;
            potential=[];
            indices = find(ohs~=0);
            for i = 1:numel(indices)
                node = nodes(ohs(indices(i)));
                if ismember(self.relayId,node.onehopset)
                    if ismember(0,node.frameInfo)
                        if node.probOfSuccess(nodes(self.relayId)) > 0.18
                            potential = [potential;ohs(indices(i))];
                        end
                    end
                end
            end
            try
                coopNodeId = potential(randi([1 numel(potential)]));
            catch
                disp("No cooperating nodes found");
            end
        end
        
        function coopNodes = findOptimalCoop(self,nodes)
            % Finding cooperating nodes for OCAMAC
            ohs = self.onehopset;
            coopNodes = [0;0];
            
            midx = (self.x+ nodes(self.relayId).x)/2;
            midy = (self.y+ nodes(self.relayId).y)/2;
            inds = find(ohs~=0);
            list = ohs(inds);
            
            list(list == self.relayId)=[];
            distances = arrayfun( @(x) nodes(x).distToXY(midx,midy), list);
            [~,indices] = sort(distances);
            coopList = list(indices(1:end));
            
            h = 1;
            for i = 1:numel(coopList)
                node = nodes(coopList(i));
                if ismember(self.relayId,node.onehopset)
                    if ismember(0,node.frameInfo)
                        if node.probOfSuccess(nodes(self.relayId)) > 0.15
                            coopNodes(h) = coopList(i);
                            h = h + 1;
                            if h == 3
                                break;
                            end
                        end
                    end
                end
            end
            
        end
        
        function slot = findRandomCoopSlot(self)
            if numel(self.frameInfo) > 60
                disp("COop large Frameinfo");
                for l = 1:numel(self.frameInfo)
                    disp(l + ":"+ self.frameInfo(l));
                end
            end
            zeroFI = find(self.frameInfo == 0);
            slot = zeroFI(randi([1 numel(zeroFI)]));
            disp("Random coopslot:"+slot);
        end
        
        function self = findFirstFreeCoopSlot(self)
            if numel(self.frameInfo) > 60
                disp("COop large Frameinfo1");
                for l = 1:numel(self.frameInfo)
                    disp(l + ":"+ self.frameInfo(l));
                end
            end
            zeroFI = find(self.frameInfo == 0);
            self.cooperatingSlot = zeroFI(1);
        end
        
        function self = findSecondFreeCoopSlot(self)
            if numel(self.frameInfo) > 60
                disp("COop large Frameinfo2");
                for l = 1:numel(self.frameInfo)
                    disp(l + ":"+ self.frameInfo(l));
                end
            end
            zeroFI = find(self.frameInfo == 0);
            self.cooperatingSlot = zeroFI(2);
        end
        
        function dist = distToXY(self,x,y)
            %Find distance between two nodes
            dist = norm([self.x;self.y] - [x;y]);
        end
        
        %%%%%%%%%% Send data%%%%%%%%%%%%%%%%%%%
        function [nextNodeId,nodes] = sendData(self,nodes,current_slot,protocol)
            % Send datapacket
            nextNodeId = self.id;
            if self.acquiredSlot == current_slot
                if self.cooperatingSlot == 0
                    relay = self.relayId;
                    if nodes(relay).onehopset(current_slot) == self.id
                        if rand < self.relayProb 
                            nextNodeId = relay;
                            disp(relay);
                            disp("To:"+ nodes(relay).relayId);
                        end
                    end
                    if nextNodeId == self.id
                        disp("collision");
                        if protocol == "cahmac"
                            coopNodeId = self.findRandomCoop(nodes);
                            disp("coopNodeId:"+coopNodeId);
                            if coopNodeId ~= 0
                                nodes(coopNodeId).cooperatingSlot = nodes(coopNodeId).findRandomCoopSlot();
                                nodes(coopNodeId).relayId = self.relayId;
                                nodes(coopNodeId).frameInfo(nodes(coopNodeId).cooperatingSlot) = coopNodeId;
                                nextNodeId = coopNodeId;
                                disp(nextNodeId + " cooperating");
                            else
                                disp("No coOp");
                            end
                        elseif protocol == "ocamac"
                            coopNodeIds = self.findOptimalCoop(nodes);
                            if coopNodeIds(1) ~= 0
                                nodes(coopNodeIds(1)) = nodes(coopNodeIds(1)).findFirstFreeCoopSlot();
                                nodes(coopNodeIds(1)).coopRelayId = self.relayId;
                                cn1 = nodes(coopNodeIds(1));
                                nodes(coopNodeIds(1)).frameInfo(cn1.cooperatingSlot) = cn1.id;
                                nodes(coopNodeIds(1)).relayId = self.relayId;
                                nodes(coopNodeIds(1)).relayPartnerId = coopNodeIds(2);
                            else
                                disp("1 no coop");
                            end
                            if coopNodeIds(2) ~= 0
                                nodes(coopNodeIds(2)) = nodes(coopNodeIds(2)).findFirstFreeCoopSlot();
                                nodes(coopNodeIds(2)).coopRelayId = self.relayId;
                                cn2 = nodes(coopNodeIds(2));
                                nodes(coopNodeIds(2)).frameInfo(cn2.cooperatingSlot) = cn2.id;
                                nodes(coopNodeIds(2)).relayId = self.relayId;
                                nodes(coopNodeIds(1)).relayPartnerId = coopNodeIds(1);
                            else
                                disp("2 no coop");
                            end
                            nextNodeId = coopNodeIds;
                            if nextNodeId(1) == 0 && nextNodeId(2) == 0
                                nextNodeId(1) = self.id;
                                nextNodeId(2) = [];
                            end
                        end
                    end
                end
                
            elseif self.cooperatingSlot == current_slot
                % Cooperative transmission by helper nodes
                relay = self.relayId;
                if relay == 0
                    nextNodeId = 0;
                elseif nodes(relay).onehopset(current_slot) == self.id || nodes(relay).onehopset(current_slot) == 0
                    if rand <= self.probOfSuccess(nodes(relay))
                        nextNodeId = relay;
                        disp(relay);
                        disp("To:"+nodes(relay).relayId);
                        nodes(self.id).cooperatingSlot = 0;
                        nodes(self.id).coopRelayId = 0;
                        nodes(self.id).frameInfo(self.cooperatingSlot) = 0;
                        try
                            if protocol == "ocamac"
                                partner = nodes(self.relayPartnerId);
                                nodes(partner.id).cooperatingSlot = 0;
                                nodes(partner.id).frameInfo(partner.cooperatingSlot)=0;
                                nodes(partner.id).relayPartnerId = 0;
                            end
                        catch
                        end
                        nodes(self.id).relayPartnerId = 0;
                    else
                        disp("Coop failed send");
                    end
                else
                    disp("Collision for cooperation");
                end
            end
            
        end
        %%%%%%%end%%%%%%%%%%%%%
        
    end
end