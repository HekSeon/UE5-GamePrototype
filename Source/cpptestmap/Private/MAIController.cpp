// Fill out your copyright notice in the Description page of Project Settings.


#include "MAIController.h"
#include "AICharacter.h"


void AMAIController::OnPossess(APawn* InPawn)
{
	Super::OnPossess(InPawn);
	
	if (AAICharacter* const ai = Cast<AAICharacter>(InPawn->GetController()))
	{
		if (BehaviorTree)
		{
			if (UBehaviorTree* const tree=ai())
			{
				UBlackboardComponent* blackboardComp;
				UseBlackboard(BlackboardData, blackboardComp);
				Blackboard = blackboardComp;
				RunBehaviorTree(tree);
			}
		}
	}
	
}
