// Fill out your copyright notice in the Description page of Project Settings.

#pragma once

#include "CoreMinimal.h"
#include "AIController.h"
#include "BehaviorTree/BehaviorTree.h"
#include "BehaviorTree/BlackboardData.h"
#include "MAIController.generated.h"

class BehaviorTree;
class UBlackboardData;

UCLASS()
class CPPTESTMAP_API AMAIController : public AAIController
{
	GENERATED_BODY()

public:
	explicit AMAIController(FObjectInitializer const& ObjectInitiliazer);

protected:
	virtual void OnPossess(APawn* InPawn) override;

private:
	UPROPERTY(EditAnywhere, Category = "AI")
	TObjectPtr<UBehaviorTree> BehaviorTree;

	UPROPERTY(EditAnywhere, Category = "AI")
	UBlackboardData* BlackboardData;

	void SetupPerception();
	
};
