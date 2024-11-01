// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {
    struct Project {
        address payable owner;
        string title;
        string description;
        uint fundingGoal;
        uint deadline;
        uint amountRaised;
        bool isFunded;
        mapping(address => uint) contributions;
    }

    Project[] public projects;

    event ProjectCreated(uint projectId, address owner, uint fundingGoal, uint deadline);
    event Funded(uint projectId, address contributor, uint amount);
    event FundWithdrawn(uint projectId, uint amount);
    event Refunded(uint projectId, address contributor, uint amount);

    modifier onlyBeforeDeadline(uint _projectId) {
        require(block.timestamp < projects[_projectId].deadline, "The project deadline has passed");
        _;
    }

    modifier onlyOwner(uint _projectId) {
        require(msg.sender == projects[_projectId].owner, "Only the project owner can call this function");
        _;
    }

    function createProject(
        string memory _title,
        string memory _description,
        uint _fundingGoal,
        uint _durationInDays
    ) public {
        require(_fundingGoal > 0, "Funding goal must be greater than zero");
        require(_durationInDays > 0, "Duration must be greater than zero");

        uint deadline = block.timestamp + (_durationInDays * 1 days);
        Project storage newProject = projects.push();
        newProject.owner = payable(msg.sender);
        newProject.title = _title;
        newProject.description = _description;
        newProject.fundingGoal = _fundingGoal;
        newProject.deadline = deadline;
        newProject.amountRaised = 0;
        newProject.isFunded = false;

        emit ProjectCreated(projects.length - 1, msg.sender, _fundingGoal, deadline);
    }

    function fundProject(uint _projectId) public payable onlyBeforeDeadline(_projectId) {
        Project storage project = projects[_projectId];
        require(msg.value > 0, "Funding amount must be greater than zero");
        require(!project.isFunded, "The project is already funded");

        project.contributions[msg.sender] += msg.value;
        project.amountRaised += msg.value;

        emit Funded(_projectId, msg.sender, msg.value);

        if (project.amountRaised >= project.fundingGoal) {
            project.isFunded = true;
        }
    }

    function withdrawFunds(uint _projectId) public onlyOwner(_projectId) {
        Project storage project = projects[_projectId];
        require(project.isFunded, "Funding goal not reached yet");
        require(project.amountRaised > 0, "No funds to withdraw");

        uint amount = project.amountRaised;
        project.amountRaised = 0;

        (bool success, ) = project.owner.call{value: amount}("");
        require(success, "Transfer failed.");

        emit FundWithdrawn(_projectId, amount);
    }

    function refund(uint _projectId) public {
        Project storage project = projects[_projectId];
        require(block.timestamp > project.deadline, "Project deadline has not yet passed");
        require(!project.isFunded, "Project is funded, no refunds");

        uint contribution = project.contributions[msg.sender];
        require(contribution > 0, "No contribution to refund");

        project.contributions[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: contribution}("");
        require(success, "Refund failed.");

        emit Refunded(_projectId, msg.sender, contribution);
    }

    function getProject(uint _projectId) public view returns (
        address owner,
        string memory title,
        string memory description,
        uint fundingGoal,
        uint deadline,
        uint amountRaised,
        bool isFunded
    ) {
        Project storage project = projects[_projectId];
        return (
            project.owner,
            project.title,
            project.description,
            project.fundingGoal,
            project.deadline,
            project.amountRaised,
            project.isFunded
        );
    }

    function getProjectCount() public view returns (uint) {
        return projects.length;
    }

    function getContribution(uint _projectId, address _contributor) public view returns (uint) {
        Project storage project = projects[_projectId];
        return project.contributions[_contributor];
    }
}
